#!/usr/bin/env python3
"""Offline unit tests for the Fre3nder Klipper/MCU lifecycle helpers."""

import copy
import hashlib
import importlib.util
from importlib.machinery import SourceFileLoader
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
LIBEXEC = ROOT / "configs/x2000/rootfs-overlay/usr/libexec/fre3nder"
BASE_MANIFEST = ROOT / "configs/x2000/f005-mcu-release.json"
sys.dont_write_bytecode = True
sys.path.insert(0, str(LIBEXEC))


def load_script(name, module_name):
    path = LIBEXEC / name
    spec = importlib.util.spec_from_loader(
        module_name, SourceFileLoader(module_name, str(path)))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


import f005_mcu
import f005_bootloader
transition_module = load_script(
    "f005-stock-to-fre3nder", "f005_stock_to_fre3nder")


class IdentityTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(BASE_MANIFEST.read_text(encoding="utf-8"))

    def observed(self, identity):
        return {
            "version": identity["version"],
            "constants": copy.deepcopy(identity["constants"]),
        }

    def test_exact_stock_and_fre3nder_classification(self):
        stock = self.observed(self.manifest["stock_identity"])
        fre3nder = self.observed(self.manifest["fre3nder_release"])
        self.assertEqual(f005_mcu.classify_identity(stock, self.manifest),
                         "stock")
        self.assertEqual(f005_mcu.classify_identity(fre3nder, self.manifest),
                         "fre3nder")

    def test_any_identity_difference_is_unknown(self):
        for key in ("version", "MCU", "CLOCK_FREQ", "SERIAL_BAUD"):
            observed = self.observed(self.manifest["stock_identity"])
            if key == "version":
                observed[key] += "-different"
            else:
                observed["constants"][key] = "different"
            self.assertEqual(
                f005_mcu.classify_identity(observed, self.manifest),
                "unknown")


class FakeProbe:
    def __init__(self, states):
        self.states = list(states)
        self.calls = []
        self.reset_count = 0

    def __call__(self, manifest, send_reset=False):
        state = self.states.pop(0)
        self.calls.append(send_reset)
        result = {"state": state, "reset_supported": True}
        if send_reset and state == "stock":
            self.reset_count += 1
            result["reset_sent"] = True
            result["connection_closed"] = True
        return result


class TransitionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.status = root / "status"
        self.status.write_text("active\n", encoding="ascii")
        self.firmware = root / "klipper-f005-mainline.bin"
        self.manifest = json.loads(BASE_MANIFEST.read_text(encoding="utf-8"))
        self.firmware.write_bytes(self.make_image())
        firmware = self.manifest["fre3nder_release"]["firmware"]
        firmware["path"] = str(self.firmware)
        firmware["size"] = self.firmware.stat().st_size
        firmware["sha256"] = hashlib.sha256(
            self.firmware.read_bytes()).hexdigest()
        self.manifest_path = root / "manifest.json"
        self.write_manifest()

    def tearDown(self):
        self.temp.cleanup()

    def make_image(self):
        image = bytearray((index * 17 + 3) & 0xff for index in range(2500))
        struct.pack_into("<II", image, 0, f005_bootloader.RAM_END,
                         f005_bootloader.APP_FLASH_START + 0x41)
        image[f005_bootloader.METADATA_OFFSET:f005_bootloader.BOARD_INFO_END] = (
            b"\0" * (f005_bootloader.BOARD_INFO_END
                       - f005_bootloader.METADATA_OFFSET))
        image[f005_bootloader.METADATA_OFFSET:
              f005_bootloader.METADATA_OFFSET + 12] = b"mcu0_004_000"
        struct.pack_into("<I", image, f005_bootloader.LENGTH_OFFSET, len(image))
        masked = bytearray(image)
        masked[f005_bootloader.CRC_OFFSET:
               f005_bootloader.LENGTH_OFFSET + 4] = b"\0" * 6
        struct.pack_into("<H", image, f005_bootloader.CRC_OFFSET,
                         f005_bootloader.crc16_ccitt(masked))
        return bytes(image)

    def write_manifest(self):
        self.manifest_path.write_text(
            json.dumps(self.manifest), encoding="utf-8")

    def run_transition(self, probe, write=False, flash=None, sleep=None):
        if flash is None:
            def flash(*args, **kwargs):
                raise AssertionError("flash must not be invoked")
        if sleep is None:
            sleep = lambda _: None
        return transition_module.transition(
            write=write, manifest_path=str(self.manifest_path),
            persistence_status=str(self.status), probe=probe, flash=flash,
            sleep=sleep)

    def test_dry_run_sends_no_reset_or_flash(self):
        probe = FakeProbe(["stock"])
        self.assertEqual(self.run_transition(probe), "dry-run-ready")
        self.assertEqual(probe.calls, [False])
        self.assertEqual(probe.reset_count, 0)

    def test_bad_firmware_hash_blocks_before_probe(self):
        self.manifest["fre3nder_release"]["firmware"]["sha256"] = "0" * 64
        self.write_manifest()
        probe = FakeProbe(["stock"])
        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True)
        self.assertEqual(probe.calls, [])

    def test_unknown_mcu_blocks_flash_and_reset_confirmation(self):
        probe = FakeProbe(["unknown"])
        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True)
        self.assertEqual(probe.reset_count, 0)

    def test_write_resets_once_flashes_once_and_reidentifies(self):
        probe = FakeProbe(["stock", "fre3nder"])
        calls = []
        sleeps = []

        def flash(image, policy):
            calls.append((image, policy))

        self.assertEqual(self.run_transition(
            probe, write=True, flash=flash, sleep=sleeps.append),
                         "transition-complete")
        self.assertEqual(probe.reset_count, 1)
        self.assertEqual(probe.calls, [True, False])
        self.assertEqual(len(calls), 1)
        self.assertEqual(sleeps, [1.0])

    def test_missing_uart_cleanup_blocks_flash(self):
        def probe(manifest, send_reset=False):
            return {
                "state": "stock",
                "reset_supported": True,
                "reset_sent": send_reset,
            }

        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True)

    def test_flash_failure_has_no_second_attempt(self):
        probe = FakeProbe(["stock"])
        calls = []

        def flash(image, policy):
            calls.append((image, policy))
            raise f005_bootloader.FlasherError("fixture failure")

        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True, flash=flash)

        self.assertEqual(probe.reset_count, 1)
        self.assertEqual(probe.calls, [True])
        self.assertEqual(len(calls), 1)

    def test_final_fre3nder_identity_is_required(self):
        probe = FakeProbe(["stock", "unknown"])
        calls = []
        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True,
                                flash=lambda image, policy: calls.append(image))
        self.assertEqual(len(calls), 1)


if __name__ == "__main__":
    unittest.main()
