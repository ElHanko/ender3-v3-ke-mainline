"""Fail-closed F005 bootloader protocol for an already-entered bootloader.

SPDX-License-Identifier: MIT
"""

from dataclasses import dataclass
import hashlib
import os
import re
import stat
import struct


UART_PATH = "/dev/ttyS1"
BOOTLOADER_BAUD = 115200
HANDSHAKE = b"\x75"
VERSION_REQUEST = b"\x00\xff"
UPDATE_REQUEST = b"\x01\xfe"
APP_START_REQUEST = b"\x02\xfd"
SECTOR_SIZE_REQUEST = b"\x03\xfc"

STATUS_CHUNK_ACCEPTED = 0x75
STATUS_COMPLETE = 0x20
STATUS_FLASH_ERROR = 0x21
STATUS_CHECKSUM_ERROR = 0x1f

METADATA_OFFSET = 0x200
METADATA_TEXT_SIZE = 12
CRC_OFFSET = 0x20c
LENGTH_OFFSET = 0x20e
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

    def close(self):
        raise NotImplementedError

    def write(self, data):
        raise NotImplementedError

    def read(self, size):
        raise NotImplementedError


class SerialTransport(Transport):
    """PySerial adapter for the qualified F005 bootloader UART."""

    def __init__(self, port=UART_PATH, baudrate=BOOTLOADER_BAUD, timeout=2.0):
        if port != UART_PATH or baudrate != BOOTLOADER_BAUD:
            raise FlasherError("F005 bootloader requires /dev/ttyS1 at 115200")
        try:
            import serial
        except ImportError as exc:
            raise FlasherError("pyserial is required for F005 bootloader access") from exc
        self._serial = serial.Serial(port, baudrate=baudrate, timeout=timeout)

    def write(self, data):
        return self._serial.write(data)

    def read(self, size):
        return self._serial.read(size)

    def close(self):
        if self._serial is not None:
            self._serial.close()
            self._serial = None


def wire_checksum(data):
    return (sum(data) & 0xff) ^ 0xff


def crc16_ccitt(data):
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xffff
            else:
                crc = (crc << 1) & 0xffff
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
        if (self.expected_sha256 is None
                or SHA256_RE.fullmatch(self.expected_sha256) is None):
            raise FlasherError("flash policy lacks a lowercase SHA-256")
        if not self.allowed_hardware_ids:
            raise FlasherError("flash policy lacks an explicit hardware allow-list")
        for hardware_id in self.allowed_hardware_ids:
            if BOOTLOADER_ID_RE.fullmatch(
                    hardware_id + "-mcu0_000_000") is None:
                raise FlasherError("invalid hardware id in allow-list")


def validate_image(image, policy):
    """Validate the F005 image structure and exact release policy."""
    policy.require_flash_policy()
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
    if image_id != policy.expected_version:
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
    if len(image) != policy.expected_size:
        raise FlasherError("image size does not match policy")
    if digest != policy.expected_sha256:
        raise FlasherError("image SHA-256 does not match policy")
    return ImageInfo(target_type, image_id, len(image), stored_crc, computed_crc,
                     digest, initial_sp, reset_vector)


def image_policy_from_manifest(manifest):
    firmware = manifest.get("fre3nder_release", {}).get("firmware", {})
    firmware_path = firmware.get("path")
    expected_size = firmware.get("size")
    expected_sha256 = firmware.get("sha256")
    expected_bootloader = firmware.get("bootloader_identity")
    if not isinstance(firmware_path, str):
        raise FlasherError("release manifest lacks firmware path")
    if not isinstance(expected_bootloader, str):
        raise FlasherError("release manifest lacks bootloader identity")
    identity = BootloaderIdentity.parse(expected_bootloader)
    policy = ImagePolicy(
        expected_version=identity.firmware,
        expected_size=expected_size,
        expected_sha256=expected_sha256,
        allowed_hardware_ids=(identity.hardware,),
    )
    policy.require_flash_policy()
    return firmware_path, policy


def load_validated_image(manifest):
    firmware_path, policy = image_policy_from_manifest(manifest)
    try:
        mode = os.lstat(firmware_path).st_mode
    except OSError as exc:
        raise FlasherError("target firmware is missing") from exc
    if not stat.S_ISREG(mode) or stat.S_ISLNK(mode):
        raise FlasherError("target firmware is linked or non-regular")
    with open(firmware_path, "rb") as stream:
        image = stream.read()
    return image, policy, validate_image(image, policy)


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
    def __init__(self, transport):
        self.transport = transport

    def _write(self, payload, operation):
        if self.transport.write(payload) != len(payload):
            raise FlasherError("short write during %s" % operation)

    def _status(self, operation):
        return decode_status(self.transport.read(2), operation)

    def handshake(self):
        self._write(HANDSHAKE, "handshake")
        if self.transport.read(1) != HANDSHAKE:
            raise FlasherError("bootloader handshake timed out or was rejected")

    def read_identity(self):
        self._write(VERSION_REQUEST, "version request")
        response = self.transport.read(26)
        if len(response) != 26:
            raise FlasherError("version response is not 26 bytes")
        if response[-1] != wire_checksum(response[:-1]):
            raise FlasherError("version response checksum failed")
        try:
            return BootloaderIdentity.parse(response[:-1].decode("ascii"))
        except UnicodeDecodeError as exc:
            raise FlasherError("bootloader identity is not ASCII") from exc

    def identify(self):
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
        if not 1 <= sector_size <= 0xff:
            raise FlasherError("invalid sector-size multiplier")
        self._write(UPDATE_REQUEST, "update request")
        if self._status("update request") != STATUS_CHUNK_ACCEPTED:
            raise FlasherError("update request did not return 0x75")
        size_bytes = struct.pack("<I", len(image))
        self._write(size_bytes + bytes((wire_checksum(size_bytes),)),
                    "firmware length")
        if self._status("firmware length") != STATUS_CHUNK_ACCEPTED:
            raise FlasherError("firmware length did not return 0x75")

        chunk_size = sector_size * 1024
        offset = 0
        while offset < len(image):
            chunk = image[offset:offset + chunk_size]
            self._write(chunk + bytes((wire_checksum(chunk),)),
                        "firmware chunk at offset %d" % offset)
            status = self._status("firmware chunk at offset %d" % offset)
            offset += len(chunk)
            if status == STATUS_COMPLETE and offset != len(image):
                raise FlasherError("bootloader completed before the full image")
            if status == STATUS_CHUNK_ACCEPTED and offset == len(image):
                raise FlasherError("final firmware chunk lacked completion status")

    def start_application(self):
        self._write(APP_START_REQUEST, "application start")
        if self._status("application start") != STATUS_CHUNK_ACCEPTED:
            raise FlasherError("application start was not acknowledged")


def flash_image(image, policy, port=UART_PATH, transport_factory=SerialTransport):
    """Perform exactly one bootloader-validated F005 image transfer."""
    info = validate_image(image, policy)
    transport = transport_factory(port, BOOTLOADER_BAUD)
    try:
        protocol = F005Protocol(transport)
        identity = protocol.identify()
        if identity.hardware not in policy.allowed_hardware_ids:
            raise FlasherError("hardware identity is not explicitly allowed")
        protocol.transfer_image(image, protocol.read_sector_size())
        protocol.start_application()
        return info, identity
    finally:
        transport.close()
