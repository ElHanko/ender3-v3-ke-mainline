#!/usr/bin/env python3
"""Offline-first research implementation of the Creality F005 protocol.

SPDX-License-Identifier: MIT

The wire-protocol provenance is documented in
``research/docs/f005-open-mcu-flasher.md``.  This is research code, not a
qualified production updater.  Importing this module performs no I/O.
"""

import argparse
from dataclasses import asdict, dataclass
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import time


APP_BAUD = 230400
BOOTLOADER_BAUD = 115200
BOOTLOADER_REQUEST = b" \x1c Request Serial Bootloader!! ~"
HANDSHAKE = b"\x75"
VERSION_REQUEST = b"\x00\xff"
UPDATE_REQUEST = b"\x01\xfe"
APP_START_REQUEST = b"\x02\xfd"
SECTOR_SIZE_REQUEST = b"\x03\xfc"

STATUS_CHUNK_ACCEPTED = 0x75
STATUS_COMPLETE = 0x20
STATUS_FLASH_ERROR = 0x21
STATUS_CHECKSUM_ERROR = 0x1F

METADATA_OFFSET = 0x200
METADATA_TEXT_SIZE = 12
CRC_OFFSET = 0x20C
LENGTH_OFFSET = 0x20E
BOARD_INFO_END = 0x220
APP_FLASH_START = 0x08003000
APP_FLASH_END = 0x08040000
RAM_START = 0x20000000
RAM_END = 0x20010000

IMAGE_ID_RE = re.compile(r"(?P<target>[a-z0-9]{4})_(?P<version>[0-9]{3})_000")
BOOTLOADER_ID_RE = re.compile(
    r"(?P<hardware>mcu[0-9]+_[0-9]{3}_[A-Z][A-Z0-9]{2})-"
    r"(?P<firmware>mcu[0-9]+_[0-9]{3}_[0-9]{3})"
)
SHA256_RE = re.compile(r"[0-9a-f]{64}")


class FlasherError(Exception):
    """Fail-closed protocol, image, or policy error."""


class Transport:
    """Small injectable interface used by the protocol and fake tests."""

    def set_baudrate(self, baudrate):
        raise NotImplementedError

    def drain(self):
        raise NotImplementedError

    def close(self):
        raise NotImplementedError

    def open(self, baudrate):
        raise NotImplementedError

    def write(self, data):
        raise NotImplementedError

    def read(self, size):
        raise NotImplementedError


class SerialTransport(Transport):
    """PySerial adapter. It is constructed only by an explicit live CLI action."""

    def __init__(self, port, baudrate, timeout=2.0):
        try:
            import serial
        except ImportError as exc:
            raise FlasherError("pyserial is required for live serial actions") from exc
        self._serial_module = serial
        self._port = port
        self._timeout = timeout
        self._serial = None
        self.open(baudrate)

    def set_baudrate(self, baudrate):
        self._serial.baudrate = baudrate

    def drain(self):
        self._serial.flush()

    def open(self, baudrate):
        if self._serial is not None and self._serial.is_open:
            raise FlasherError("serial transport is already open")
        self._serial = self._serial_module.Serial(
            self._port,
            baudrate=baudrate,
            timeout=self._timeout,
        )

    def write(self, data):
        return self._serial.write(data)

    def read(self, size):
        return self._serial.read(size)

    def close(self):
        if self._serial is not None:
            self._serial.close()
            self._serial = None


def wire_checksum(data):
    return (sum(data) & 0xFF) ^ 0xFF


def crc16_ccitt(data):
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


@dataclass(frozen=True)
class BootloaderIdentity:
    raw: str
    hardware: str
    firmware: str

    @classmethod
    def parse(cls, value):
        match = BOOTLOADER_ID_RE.fullmatch(value)
        if match is None:
            raise FlasherError("unexpected bootloader identity format")
        return cls(value, match.group("hardware"), match.group("firmware"))


@dataclass(frozen=True)
class ImageInfo:
    target_type: str
    version: str
    size: int
    stored_crc16: int
    computed_crc16: int
    sha256: str
    initial_stack_pointer: int
    reset_vector: int


@dataclass(frozen=True)
class ImagePolicy:
    target_type: str = "mcu0"
    expected_version: str = None
    expected_size: int = None
    expected_sha256: str = None
    allowed_hardware_ids: tuple = ()

    def require_flash_policy(self):
        if self.expected_version is None:
            raise FlasherError("flash policy lacks an expected image version")
        if self.expected_size is None or self.expected_size <= 0:
            raise FlasherError("flash policy lacks a positive expected image size")
        if (self.expected_sha256 is None or
                SHA256_RE.fullmatch(self.expected_sha256) is None):
            raise FlasherError("flash policy lacks a lowercase SHA-256")
        if not self.allowed_hardware_ids:
            raise FlasherError("flash policy lacks an explicit hardware allow-list")
        for hardware_id in self.allowed_hardware_ids:
            if BOOTLOADER_ID_RE.fullmatch(
                    hardware_id + "-mcu0_000_000") is None:
                raise FlasherError("invalid hardware id in allow-list")


def validate_image(image, policy=None):
    """Validate the Fre3nder F005 image structure and optional exact policy."""
    if policy is None:
        policy = ImagePolicy()
    if len(image) < BOARD_INFO_END:
        raise FlasherError("image is too short for the F005 board-info region")
    if len(image) > APP_FLASH_END - APP_FLASH_START:
        raise FlasherError("image exceeds the qualified Fre3nder flash boundary")

    try:
        image_id = image[METADATA_OFFSET:
                         METADATA_OFFSET + METADATA_TEXT_SIZE].decode("ascii")
    except UnicodeDecodeError as exc:
        raise FlasherError("image identity is not ASCII") from exc
    match = IMAGE_ID_RE.fullmatch(image_id)
    if match is None:
        raise FlasherError("invalid F005 image identity")
    target_type = match.group("target")
    if target_type != policy.target_type:
        raise FlasherError("image target type does not match policy")
    if policy.expected_version is not None and image_id != policy.expected_version:
        raise FlasherError("image version does not match policy")

    stored_crc = struct.unpack_from("<H", image, CRC_OFFSET)[0]
    stored_length = struct.unpack_from("<I", image, LENGTH_OFFSET)[0]
    if stored_length != len(image):
        raise FlasherError("stored image length does not match file size")
    if any(image[LENGTH_OFFSET + 4:BOARD_INFO_END]):
        raise FlasherError("reserved F005 board-info bytes are not zero")

    initial_sp, reset_vector = struct.unpack_from("<II", image, 0)
    if not RAM_START <= initial_sp <= RAM_END:
        raise FlasherError("initial stack pointer is outside F005 RAM")
    if reset_vector & 1 == 0:
        raise FlasherError("reset vector does not select Thumb state")
    reset_target = reset_vector & ~1
    if not APP_FLASH_START <= reset_target < APP_FLASH_END:
        raise FlasherError("reset vector is outside the F005 application range")

    masked = bytearray(image)
    masked[CRC_OFFSET:LENGTH_OFFSET + 4] = b"\0" * 6
    computed_crc = crc16_ccitt(masked)
    if stored_crc != computed_crc:
        raise FlasherError("image CRC16 does not match")

    digest = hashlib.sha256(image).hexdigest()
    if policy.expected_size is not None and len(image) != policy.expected_size:
        raise FlasherError("image size does not match policy")
    if policy.expected_sha256 is not None and digest != policy.expected_sha256:
        raise FlasherError("image SHA-256 does not match policy")

    return ImageInfo(
        target_type=target_type,
        version=image_id,
        size=len(image),
        stored_crc16=stored_crc,
        computed_crc16=computed_crc,
        sha256=digest,
        initial_stack_pointer=initial_sp,
        reset_vector=reset_vector,
    )


def decode_status(response, operation):
    if len(response) != 2:
        raise FlasherError("%s response is not two bytes" % operation)
    if response[1] != wire_checksum(response[:1]):
        raise FlasherError("%s response checksum failed" % operation)
    status = response[0]
    if status == STATUS_FLASH_ERROR:
        raise FlasherError("%s reported flash write error (0x21)" % operation)
    if status == STATUS_CHECKSUM_ERROR:
        raise FlasherError("%s reported data checksum error (0x1f)" % operation)
    if status not in (STATUS_CHUNK_ACCEPTED, STATUS_COMPLETE):
        raise FlasherError("%s returned unknown status 0x%02x" %
                           (operation, status))
    return status


class F005Protocol:
    def __init__(self, transport, sleep=time.sleep):
        self.transport = transport
        self.sleep = sleep

    def _write(self, payload, operation):
        if self.transport.write(payload) != len(payload):
            raise FlasherError("short write during %s" % operation)

    def _status(self, operation):
        return decode_status(self.transport.read(2), operation)

    def handshake(self):
        self._write(HANDSHAKE, "handshake")
        response = self.transport.read(1)
        if response != HANDSHAKE:
            raise FlasherError("bootloader handshake timed out or was rejected")

    def request_bootloader(self):
        self.transport.set_baudrate(APP_BAUD)
        self._write(BOOTLOADER_REQUEST, "serial bootloader request")
        self.transport.drain()
        self.transport.close()
        self.sleep(1.0)
        self.transport.open(BOOTLOADER_BAUD)
        self.handshake()

    def read_identity(self):
        self._write(VERSION_REQUEST, "version request")
        response = self.transport.read(26)
        if len(response) != 26:
            raise FlasherError("version response is not 26 bytes")
        if response[-1] != wire_checksum(response[:-1]):
            raise FlasherError("version response checksum failed")
        try:
            value = response[:-1].decode("ascii")
        except UnicodeDecodeError as exc:
            raise FlasherError("bootloader identity is not ASCII") from exc
        return BootloaderIdentity.parse(value)

    def identify(self, request_bootloader=False):
        if request_bootloader:
            self.request_bootloader()
        else:
            self.transport.set_baudrate(BOOTLOADER_BAUD)
            self.handshake()
        return self.read_identity()

    def read_sector_size(self):
        self._write(SECTOR_SIZE_REQUEST, "sector-size request")
        response = self.transport.read(2)
        if len(response) != 2:
            raise FlasherError("sector-size response is not two bytes")
        if response[-1] != wire_checksum(response[:-1]):
            raise FlasherError("sector-size response checksum failed")
        if response[0] == 0:
            raise FlasherError("bootloader returned zero sector size")
        return response[0]

    def transfer_image(self, image, sector_size):
        if not image:
            raise FlasherError("refusing to transfer an empty image")
        if not 1 <= sector_size <= 0xFF:
            raise FlasherError("invalid sector-size multiplier")

        self._write(UPDATE_REQUEST, "update request")
        if self._status("update request") != STATUS_CHUNK_ACCEPTED:
            raise FlasherError("update request did not return 0x75")

        size_bytes = struct.pack("<I", len(image))
        size_frame = size_bytes + bytes((wire_checksum(size_bytes),))
        self._write(size_frame, "firmware length")
        if self._status("firmware length") != STATUS_CHUNK_ACCEPTED:
            raise FlasherError("firmware length did not return 0x75")

        chunk_size = sector_size * 1024
        offset = 0
        while offset < len(image):
            chunk = image[offset:offset + chunk_size]
            frame = chunk + bytes((wire_checksum(chunk),))
            self._write(frame, "firmware chunk at offset %d" % offset)
            status = self._status("firmware chunk at offset %d" % offset)
            offset += len(chunk)
            final_chunk = offset == len(image)
            if status == STATUS_COMPLETE and not final_chunk:
                raise FlasherError("bootloader completed before the full image")
            if status == STATUS_CHUNK_ACCEPTED and final_chunk:
                raise FlasherError("final firmware chunk lacked completion status")

    def start_application(self):
        self._write(APP_START_REQUEST, "application start")
        if self._status("application start") != STATUS_CHUNK_ACCEPTED:
            raise FlasherError("application start was not acknowledged")


class F005Flasher:
    def __init__(self, protocol):
        self.protocol = protocol

    def flash(self, image, policy, request_bootloader=False):
        policy.require_flash_policy()
        info = validate_image(image, policy)

        identity = self.protocol.identify(
            request_bootloader=request_bootloader)
        if identity.hardware not in policy.allowed_hardware_ids:
            raise FlasherError("hardware identity is not explicitly allowed")

        sector_size = self.protocol.read_sector_size()
        self.protocol.transfer_image(image, sector_size)
        self.protocol.start_application()
        return info, identity


def _policy_from_args(args, require_allowlist=False):
    allowed = tuple(getattr(args, "allow_hw_id", None) or ())
    policy = ImagePolicy(
        expected_version=getattr(args, "expected_version", None),
        expected_size=getattr(args, "expected_size", None),
        expected_sha256=getattr(args, "expected_sha256", None),
        allowed_hardware_ids=allowed,
    )
    if require_allowlist:
        policy.require_flash_policy()
    return policy


def _add_image_policy_arguments(parser, required):
    parser.add_argument("--expected-version", required=required,
                        help="exact image identity, for example mcu0_004_000")
    parser.add_argument("--expected-size", required=required, type=int)
    parser.add_argument("--expected-sha256", required=required)


def build_argument_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest="action", required=True)

    inspect_parser = actions.add_parser("inspect", help="inspect an image offline")
    inspect_parser.add_argument("image", type=Path)

    validate_parser = actions.add_parser("validate", help="validate an image offline")
    validate_parser.add_argument("image", type=Path)
    _add_image_policy_arguments(validate_parser, required=False)

    identify_parser = actions.add_parser(
        "identify", help="future live identity query; never used by offline tests")
    identify_parser.add_argument("port")
    identify_parser.add_argument("--request-bootloader", action="store_true")

    flash_parser = actions.add_parser(
        "flash", help="future explicitly gated flash; not hardware-qualified")
    flash_parser.add_argument("port")
    flash_parser.add_argument("image", type=Path)
    _add_image_policy_arguments(flash_parser, required=True)
    flash_parser.add_argument("--allow-hw-id", action="append", required=True,
                              help="exact allowed hardware id; repeatable")
    flash_parser.add_argument("--request-bootloader", action="store_true")
    return parser


def main(argv=None):
    args = build_argument_parser().parse_args(argv)
    try:
        if args.action in ("inspect", "validate"):
            image = args.image.read_bytes()
            policy = (ImagePolicy() if args.action == "inspect"
                      else _policy_from_args(args))
            info = validate_image(image, policy)
            print(json.dumps(asdict(info), indent=2, sort_keys=True))
            return 0

        image = None
        policy = None
        if args.action == "flash":
            image = args.image.read_bytes()
            policy = _policy_from_args(args, require_allowlist=True)
            validate_image(image, policy)

        transport = SerialTransport(
            args.port,
            APP_BAUD if args.request_bootloader else BOOTLOADER_BAUD,
        )
        try:
            protocol = F005Protocol(transport)
            if args.action == "identify":
                identity = protocol.identify(args.request_bootloader)
                print(json.dumps(asdict(identity), indent=2, sort_keys=True))
                return 0

            info, identity = F005Flasher(protocol).flash(
                image, policy, args.request_bootloader)
            print(json.dumps({
                "image": asdict(info),
                "identity": asdict(identity),
                "result": "flash-and-app-start-complete",
            }, indent=2, sort_keys=True))
            return 0
        finally:
            transport.close()
    except (FlasherError, OSError) as exc:
        print("f005-flasher: FAIL CLOSED: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
