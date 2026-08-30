#!/usr/bin/env python3
"""Offline fake-transport tests for the productive F005 bootloader module."""

import hashlib
import struct
import sys
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
LIBEXEC = ROOT / "configs/x2000/rootfs-overlay/usr/libexec/fre3nder"
sys.dont_write_bytecode = True
sys.path.insert(0, str(LIBEXEC))

import f005_bootloader as flasher


KNOWN_IDENTITY = "mcu0_001_G32-mcu0_004_000"
KNOWN_HARDWARE = "mcu0_001_G32"


def status_frame(status):
    return bytes((status, flasher.wire_checksum(bytes((status,)))))


def make_image(size=2500, identity="mcu0_004_000"):
    image = bytearray((index * 17 + 3) & 0xff for index in range(size))
    struct.pack_into("<II", image, 0, flasher.RAM_END,
                     flasher.APP_FLASH_START + 0x41)
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
        self.closed = False

    def close(self):
        self.closed = True

    def write(self, data):
        self.writes.append(bytes(data))
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
        self.inbox = b""
        self.expecting_size = False
        self.expected_size = None
        self.received = bytearray()
        self.size_frame = None
        self.app_started = False
        self.closed = False

    def close(self):
        self.closed = True

    def _reply(self, status):
        self.inbox = status_frame(status)

    def write(self, data):
        data = bytes(data)
        self.writes.append(data)
        if data == flasher.HANDSHAKE:
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
                status = (self.chunk_statuses.pop(0) if self.chunk_statuses
                          else (flasher.STATUS_COMPLETE
                                if len(self.received) >= self.expected_size
                                else flasher.STATUS_CHUNK_ACCEPTED))
                self._reply(status)
        return len(data)

    def read(self, size):
        response, self.inbox = self.inbox[:size], self.inbox[size:]
        return response


def transport_factory(transport):
    def factory(port, baudrate):
        if port != flasher.UART_PATH or baudrate != flasher.BOOTLOADER_BAUD:
            raise AssertionError("unexpected bootloader transport settings")
        return transport
    return factory


class ProtocolTests(unittest.TestCase):
    def test_handshake_success_and_failure(self):
        transport = ScriptedTransport([flasher.HANDSHAKE])
        flasher.F005Protocol(transport).handshake()
        self.assertEqual(transport.writes, [flasher.HANDSHAKE])
        with self.assertRaisesRegex(flasher.FlasherError, "handshake"):
            flasher.F005Protocol(ScriptedTransport([b""])).handshake()

    def test_identity_checksum_and_hardware(self):
        payload = KNOWN_IDENTITY.encode("ascii")
        identity = flasher.F005Protocol(ScriptedTransport([
            payload + bytes((flasher.wire_checksum(payload),))
        ])).read_identity()
        self.assertEqual(identity.hardware, KNOWN_HARDWARE)
        self.assertEqual(identity.firmware, "mcu0_004_000")
        with self.assertRaisesRegex(flasher.FlasherError, "checksum"):
            flasher.F005Protocol(ScriptedTransport([payload + b"\0"])).read_identity()

    def test_sector_size_and_status_errors(self):
        payload = b"\x02"
        self.assertEqual(flasher.F005Protocol(ScriptedTransport([
            payload + bytes((flasher.wire_checksum(payload),))
        ])).read_sector_size(), 2)
        for status in (flasher.STATUS_FLASH_ERROR,
                       flasher.STATUS_CHECKSUM_ERROR, 0x42):
            with self.subTest(status=status):
                with self.assertRaises(flasher.FlasherError):
                    flasher.decode_status(status_frame(status), "test")

    def test_app_start_requires_ack(self):
        transport = ScriptedTransport([status_frame(flasher.STATUS_CHUNK_ACCEPTED)])
        flasher.F005Protocol(transport).start_application()
        self.assertEqual(transport.writes, [flasher.APP_START_REQUEST])


class ImageTests(unittest.TestCase):
    def test_image_validation_and_allowlist(self):
        image = make_image()
        info = flasher.validate_image(image, exact_policy(image))
        self.assertEqual(info.version, "mcu0_004_000")
        self.assertEqual(info.stored_crc16, info.computed_crc16)
        with self.assertRaisesRegex(flasher.FlasherError, "allow-list"):
            flasher.validate_image(image, exact_policy(image, allowed=()))
        invalid = bytearray(image)
        invalid[-1] ^= 1
        with self.assertRaisesRegex(flasher.FlasherError, "CRC16"):
            flasher.validate_image(bytes(invalid), exact_policy(image))


class FlashTests(unittest.TestCase):
    def test_transfer_length_chunking_final_status_and_app_start(self):
        image = make_image(size=2500)
        transport = FakeBootloader(sector_size=1)
        info, identity = flasher.flash_image(
            image, exact_policy(image), transport_factory=transport_factory(transport))
        self.assertEqual(info.size, len(image))
        self.assertEqual(identity.hardware, KNOWN_HARDWARE)
        self.assertEqual(transport.size_frame[:4], struct.pack("<I", len(image)))
        self.assertEqual(bytes(transport.received), image)
        chunks = [frame for frame in transport.writes
                  if len(frame) not in (1, 2, 5, 26)]
        self.assertEqual([len(frame) - 1 for frame in chunks], [1024, 1024, 452])
        self.assertTrue(transport.app_started)
        self.assertTrue(transport.closed)

    def test_unallowed_hardware_stops_before_transfer(self):
        image = make_image()
        transport = FakeBootloader(identity="mcu0_002_G32-mcu0_004_000")
        with self.assertRaisesRegex(flasher.FlasherError, "not explicitly allowed"):
            flasher.flash_image(image, exact_policy(image),
                                transport_factory=transport_factory(transport))
        self.assertNotIn(flasher.UPDATE_REQUEST, transport.writes)

    def test_update_ack_is_required(self):
        image = make_image(size=700)
        with self.assertRaisesRegex(flasher.FlasherError, "did not return 0x75"):
            flasher.F005Protocol(
                ScriptedTransport([status_frame(flasher.STATUS_COMPLETE)])
            ).transfer_image(image, 1)

    def test_final_chunk_requires_complete_status(self):
        image = make_image(size=700)
        transport = FakeBootloader(chunk_statuses=[flasher.STATUS_CHUNK_ACCEPTED])
        with self.assertRaises(flasher.FlasherError):
            flasher.flash_image(image, exact_policy(image),
                                transport_factory=transport_factory(transport))

    def test_flash_error_has_no_second_attempt(self):
        image = make_image(size=700)
        transport = FakeBootloader(chunk_statuses=[flasher.STATUS_FLASH_ERROR])
        with self.assertRaises(flasher.FlasherError):
            flasher.flash_image(image, exact_policy(image),
                                transport_factory=transport_factory(transport))
        self.assertEqual(transport.writes.count(flasher.UPDATE_REQUEST), 1)
        self.assertFalse(transport.app_started)


if __name__ == "__main__":
    unittest.main()
