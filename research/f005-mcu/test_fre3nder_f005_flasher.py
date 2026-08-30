#!/usr/bin/env python3
"""Offline fake-transport tests for the Fre3nder F005 research flasher.

SPDX-License-Identifier: MIT
"""

import hashlib
import struct
import unittest

import fre3nder_f005_flasher as flasher


KNOWN_IDENTITY = "mcu0_001_G32-mcu0_004_000"
KNOWN_HARDWARE = "mcu0_001_G32"


def status_frame(status):
    return bytes((status, flasher.wire_checksum(bytes((status,)))))


def make_image(size=2500, identity="mcu0_004_000"):
    image = bytearray((index * 17 + 3) & 0xFF for index in range(size))
    struct.pack_into("<II", image, 0, flasher.RAM_END, flasher.APP_FLASH_START + 0x41)
    image[flasher.METADATA_OFFSET:flasher.BOARD_INFO_END] = (
        b"\0" * (flasher.BOARD_INFO_END - flasher.METADATA_OFFSET))
    image[flasher.METADATA_OFFSET:
          flasher.METADATA_OFFSET + 12] = identity.encode("ascii")
    struct.pack_into("<I", image, flasher.LENGTH_OFFSET, len(image))
    masked = bytearray(image)
    masked[flasher.CRC_OFFSET:flasher.LENGTH_OFFSET + 4] = b"\0" * 6
    struct.pack_into("<H", image, flasher.CRC_OFFSET,
                     flasher.crc16_ccitt(masked))
    return bytes(image)


def exact_policy(image, allowed=(KNOWN_HARDWARE,)):
    return flasher.ImagePolicy(
        expected_version="mcu0_004_000",
        expected_size=len(image),
        expected_sha256=hashlib.sha256(image).hexdigest(),
        allowed_hardware_ids=allowed,
    )


class ScriptedTransport(flasher.Transport):
    def __init__(self, responses):
        self.responses = list(responses)
        self.writes = []
        self.baudrates = []
        self.events = []

    def set_baudrate(self, baudrate):
        self.baudrates.append(baudrate)
        self.events.append(("baudrate", baudrate))

    def drain(self):
        self.events.append(("drain",))

    def close(self):
        self.events.append(("close",))

    def open(self, baudrate):
        self.baudrates.append(baudrate)
        self.events.append(("open", baudrate))

    def write(self, data):
        self.writes.append(bytes(data))
        self.events.append(("write", bytes(data)))
        return len(data)

    def read(self, size):
        if not self.responses:
            return b""
        return self.responses.pop(0)


class FakeBootloader(flasher.Transport):
    def __init__(self, identity=KNOWN_IDENTITY, sector_size=1,
                 chunk_statuses=None):
        self.identity = identity.encode("ascii")
        self.sector_size = sector_size
        self.chunk_statuses = list(chunk_statuses or ())
        self.writes = []
        self.baudrates = []
        self.events = []
        self.inbox = b""
        self.expecting_size = False
        self.expected_size = None
        self.received = bytearray()
        self.size_frame = None
        self.app_started = False

    def set_baudrate(self, baudrate):
        self.baudrates.append(baudrate)
        self.events.append(("baudrate", baudrate))

    def drain(self):
        self.events.append(("drain",))

    def close(self):
        self.events.append(("close",))

    def open(self, baudrate):
        self.baudrates.append(baudrate)
        self.events.append(("open", baudrate))

    def _reply(self, status):
        self.inbox = status_frame(status)

    def write(self, data):
        data = bytes(data)
        self.writes.append(data)
        self.events.append(("write", data))
        if data == flasher.BOOTLOADER_REQUEST:
            pass
        elif data == flasher.HANDSHAKE:
            self.inbox = flasher.HANDSHAKE
        elif data == flasher.VERSION_REQUEST:
            self.inbox = self.identity + bytes((flasher.wire_checksum(self.identity),))
        elif data == flasher.SECTOR_SIZE_REQUEST:
            payload = bytes((self.sector_size,))
            self.inbox = payload + bytes((flasher.wire_checksum(payload),))
        elif data == flasher.UPDATE_REQUEST:
            self.expecting_size = True
            self.received = bytearray()
            self._reply(flasher.STATUS_CHUNK_ACCEPTED)
        elif data == flasher.APP_START_REQUEST:
            self.app_started = True
            self._reply(flasher.STATUS_CHUNK_ACCEPTED)
        elif self.expecting_size:
            self.size_frame = data
            if len(data) != 5 or data[-1] != flasher.wire_checksum(data[:-1]):
                self._reply(flasher.STATUS_CHECKSUM_ERROR)
            else:
                self.expected_size = struct.unpack("<I", data[:4])[0]
                self.expecting_size = False
                self._reply(flasher.STATUS_CHUNK_ACCEPTED)
        else:
            chunk, checksum = data[:-1], data[-1]
            if checksum != flasher.wire_checksum(chunk):
                self._reply(flasher.STATUS_CHECKSUM_ERROR)
            else:
                self.received.extend(chunk)
                if self.chunk_statuses:
                    status = self.chunk_statuses.pop(0)
                elif len(self.received) >= self.expected_size:
                    status = flasher.STATUS_COMPLETE
                else:
                    status = flasher.STATUS_CHUNK_ACCEPTED
                self._reply(status)
        return len(data)

    def read(self, size):
        response, self.inbox = self.inbox[:size], self.inbox[size:]
        return response


class ProtocolTests(unittest.TestCase):
    def test_successful_handshake(self):
        transport = ScriptedTransport([flasher.HANDSHAKE])
        flasher.F005Protocol(transport).handshake()
        self.assertEqual(transport.writes, [flasher.HANDSHAKE])

    def test_handshake_timeout(self):
        transport = ScriptedTransport([b""])
        with self.assertRaisesRegex(flasher.FlasherError, "handshake"):
            flasher.F005Protocol(transport).handshake()

    def test_correct_version_and_allowed_hardware(self):
        payload = KNOWN_IDENTITY.encode("ascii")
        transport = ScriptedTransport([
            payload + bytes((flasher.wire_checksum(payload),))
        ])
        identity = flasher.F005Protocol(transport).read_identity()
        self.assertEqual(identity.hardware, KNOWN_HARDWARE)
        self.assertEqual(identity.firmware, "mcu0_004_000")
        self.assertIn(identity.hardware, (KNOWN_HARDWARE,))

    def test_short_version_is_rejected(self):
        transport = ScriptedTransport([b"short"])
        with self.assertRaisesRegex(flasher.FlasherError, "26 bytes"):
            flasher.F005Protocol(transport).read_identity()

    def test_version_checksum_is_rejected(self):
        payload = KNOWN_IDENTITY.encode("ascii")
        transport = ScriptedTransport([payload + b"\x00"])
        with self.assertRaisesRegex(flasher.FlasherError, "checksum"):
            flasher.F005Protocol(transport).read_identity()

    def test_malformed_version_is_rejected(self):
        payload = b"x" * 25
        transport = ScriptedTransport([
            payload + bytes((flasher.wire_checksum(payload),))
        ])
        with self.assertRaisesRegex(flasher.FlasherError, "identity format"):
            flasher.F005Protocol(transport).read_identity()

    def test_unallowed_hardware_is_distinct(self):
        identity = flasher.BootloaderIdentity.parse(
            "mcu0_002_G32-mcu0_004_000")
        self.assertNotIn(identity.hardware, (KNOWN_HARDWARE,))

    def test_sector_size(self):
        payload = b"\x02"
        transport = ScriptedTransport([
            payload + bytes((flasher.wire_checksum(payload),))
        ])
        self.assertEqual(flasher.F005Protocol(transport).read_sector_size(), 2)

    def test_all_known_statuses_and_unknown_status(self):
        self.assertEqual(
            flasher.decode_status(status_frame(0x75), "test"), 0x75)
        self.assertEqual(
            flasher.decode_status(status_frame(0x20), "test"), 0x20)
        with self.assertRaisesRegex(flasher.FlasherError, "0x21"):
            flasher.decode_status(status_frame(0x21), "test")
        with self.assertRaisesRegex(flasher.FlasherError, "0x1f"):
            flasher.decode_status(status_frame(0x1F), "test")
        with self.assertRaisesRegex(flasher.FlasherError, "unknown status"):
            flasher.decode_status(status_frame(0x42), "test")

    def test_app_start(self):
        transport = ScriptedTransport([status_frame(0x75)])
        flasher.F005Protocol(transport).start_application()
        self.assertEqual(transport.writes, [flasher.APP_START_REQUEST])

    def test_bootloader_request_drains_closes_and_reopens(self):
        transport = ScriptedTransport([flasher.HANDSHAKE])
        flasher.F005Protocol(transport, sleep=lambda _: None).request_bootloader()
        self.assertEqual(transport.baudrates,
                         [flasher.APP_BAUD, flasher.BOOTLOADER_BAUD])
        self.assertEqual(transport.writes,
                         [flasher.BOOTLOADER_REQUEST, flasher.HANDSHAKE])
        self.assertEqual(transport.events, [
            ("baudrate", flasher.APP_BAUD),
            ("write", flasher.BOOTLOADER_REQUEST),
            ("drain",),
            ("close",),
            ("open", flasher.BOOTLOADER_BAUD),
            ("write", flasher.HANDSHAKE),
        ])


class ImageTests(unittest.TestCase):
    def test_valid_fre3nder_image(self):
        image = make_image()
        info = flasher.validate_image(image, exact_policy(image))
        self.assertEqual(info.version, "mcu0_004_000")
        self.assertEqual(info.stored_crc16, info.computed_crc16)

    def test_wrong_target_type_is_rejected(self):
        image = make_image(identity="noz0_004_000")
        with self.assertRaisesRegex(flasher.FlasherError, "target type"):
            flasher.validate_image(image)

    def test_bad_image_crc_is_rejected(self):
        image = bytearray(make_image())
        image[-1] ^= 0x01
        with self.assertRaisesRegex(flasher.FlasherError, "CRC16"):
            flasher.validate_image(bytes(image))


class FlashTests(unittest.TestCase):
    def test_flash_request_size_multipart_remainder_and_exact_bytes(self):
        image = make_image(size=2500)
        transport = FakeBootloader(sector_size=1)
        info, identity = flasher.F005Flasher(
            flasher.F005Protocol(transport)).flash(image, exact_policy(image))
        self.assertEqual(info.size, 2500)
        self.assertEqual(identity.hardware, KNOWN_HARDWARE)
        self.assertIn(flasher.UPDATE_REQUEST, transport.writes)
        self.assertEqual(transport.expected_size, len(image))
        self.assertEqual(transport.size_frame[:4], struct.pack("<I", len(image)))
        self.assertEqual(bytes(transport.received), image)
        chunk_frames = [frame for frame in transport.writes
                        if len(frame) not in (1, 2, 5, 32)]
        self.assertEqual([len(frame) - 1 for frame in chunk_frames],
                         [1024, 1024, 452])
        self.assertTrue(transport.app_started)

    def test_invalid_image_is_rejected_before_any_transport_write(self):
        image = make_image()
        invalid = bytearray(image)
        invalid[-1] ^= 0x01
        transport = FakeBootloader()
        with self.assertRaises(flasher.FlasherError):
            flasher.F005Flasher(flasher.F005Protocol(transport)).flash(
                bytes(invalid), exact_policy(image))
        self.assertEqual(transport.writes, [])

    def test_missing_allowlist_is_rejected_before_transport_write(self):
        image = make_image()
        transport = FakeBootloader()
        with self.assertRaisesRegex(flasher.FlasherError, "allow-list"):
            flasher.F005Flasher(flasher.F005Protocol(transport)).flash(
                image, exact_policy(image, allowed=()))
        self.assertEqual(transport.writes, [])

    def test_unknown_hardware_stops_before_flash_request(self):
        image = make_image()
        transport = FakeBootloader(
            identity="mcu0_002_G32-mcu0_004_000")
        with self.assertRaisesRegex(flasher.FlasherError, "not explicitly allowed"):
            flasher.F005Flasher(flasher.F005Protocol(transport)).flash(
                image, exact_policy(image))
        self.assertNotIn(flasher.UPDATE_REQUEST, transport.writes)

    def test_flash_request_ack_is_required(self):
        image = make_image()
        protocol = flasher.F005Protocol(
            ScriptedTransport([status_frame(0x20)]))
        with self.assertRaisesRegex(flasher.FlasherError, "did not return 0x75"):
            protocol.transfer_image(image, 1)

    def test_flash_error_checksum_error_and_unknown_status_fail(self):
        image = make_image(size=700)
        for status in (0x21, 0x1F, 0x42):
            with self.subTest(status=status):
                transport = FakeBootloader(chunk_statuses=[status])
                with self.assertRaises(flasher.FlasherError):
                    flasher.F005Flasher(
                        flasher.F005Protocol(transport)).flash(
                            image, exact_policy(image))
                self.assertFalse(transport.app_started)

    def test_final_chunk_requires_complete_status(self):
        image = make_image(size=700)
        transport = FakeBootloader(chunk_statuses=[0x75])
        with self.assertRaisesRegex(flasher.FlasherError, "lacked completion"):
            flasher.F005Flasher(flasher.F005Protocol(transport)).flash(
                image, exact_policy(image))


if __name__ == "__main__":
    unittest.main()
