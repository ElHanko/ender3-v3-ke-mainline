#!/usr/bin/env python3
"""Offline unit tests for the Fre3nder Klipper/MCU lifecycle helpers."""

import copy
import hashlib
import importlib.util
from importlib.machinery import SourceFileLoader
import json
from pathlib import Path
import stat
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
        return result


class TransitionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.status = root / "status"
        self.status.write_text("active\n", encoding="ascii")
        self.tool = root / "mcu_util"
        self.tool.write_bytes(b"fixture mcu util")
        self.tool.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
        self.firmware = root / "klipper-f005-mainline.bin"
        self.firmware.write_bytes(b"fixture firmware")
        self.manifest = json.loads(BASE_MANIFEST.read_text(encoding="utf-8"))
        firmware = self.manifest["fre3nder_release"]["firmware"]
        firmware["path"] = str(self.firmware)
        firmware["size"] = self.firmware.stat().st_size
        firmware["sha256"] = hashlib.sha256(
            self.firmware.read_bytes()).hexdigest()
        self.manifest_path = root / "manifest.json"
        self.write_manifest()
        self.good_tool_hash = hashlib.sha256(self.tool.read_bytes()).hexdigest()
        self.saved_tool_hash = transition_module.MCU_UTIL_SHA256
        transition_module.MCU_UTIL_SHA256 = self.good_tool_hash

    def tearDown(self):
        transition_module.MCU_UTIL_SHA256 = self.saved_tool_hash
        self.temp.cleanup()

    def write_manifest(self):
        self.manifest_path.write_text(
            json.dumps(self.manifest), encoding="utf-8")

    def run_transition(self, probe, write=False, runner=None):
        if runner is None:
            def runner(*args, **kwargs):
                raise AssertionError("mcu_util must not be invoked")
        return transition_module.transition(
            write=write, manifest_path=str(self.manifest_path),
            mcu_util_path=str(self.tool), persistence_status=str(self.status),
            probe=probe, runner=runner)

    def test_dry_run_sends_no_reset_and_invokes_no_updater(self):
        probe = FakeProbe(["stock"])
        self.assertEqual(self.run_transition(probe), "dry-run-ready")
        self.assertEqual(probe.calls, [False])
        self.assertEqual(probe.reset_count, 0)

    def test_bad_mcu_util_hash_blocks_before_probe(self):
        transition_module.MCU_UTIL_SHA256 = "0" * 64
        probe = FakeProbe(["stock"])
        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True)
        self.assertEqual(probe.calls, [])

    def test_missing_mcu_util_blocks_before_probe(self):
        self.tool.unlink()
        probe = FakeProbe(["stock"])
        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True)
        self.assertEqual(probe.calls, [])

    def test_bad_firmware_hash_blocks_before_probe(self):
        self.manifest["fre3nder_release"]["firmware"]["sha256"] = "0" * 64
        self.write_manifest()
        probe = FakeProbe(["stock"])
        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True)
        self.assertEqual(probe.calls, [])

    def test_unknown_mcu_blocks_updater_and_reset(self):
        probe = FakeProbe(["unknown"])
        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True)
        self.assertEqual(probe.reset_count, 0)

    def test_write_resets_once_runs_c_g_u_and_reidentifies(self):
        probe = FakeProbe(["stock", "fre3nder"])
        calls = []

        class Completed:
            returncode = 0

        def runner(argv, check):
            calls.append((argv, check))
            return Completed()

        self.assertEqual(self.run_transition(probe, write=True, runner=runner),
                         "transition-complete")
        self.assertEqual(probe.reset_count, 1)
        self.assertEqual(probe.calls, [True, False])
        self.assertEqual(
            [argv[3] for argv, check in calls],
            ["-c", "-g", "-u"])
        self.assertEqual([check for argv, check in calls],
                         [False, False, False])
        self.assertEqual(calls[2][0][-2:], ["-f", str(self.firmware)])

    def test_write_stops_before_u_when_g_fails(self):
        probe = FakeProbe(["stock"])
        calls = []

        class Completed:
            def __init__(self, returncode):
                self.returncode = returncode

        def runner(argv, check):
            calls.append((argv, check))
            return Completed(1 if argv[3] == "-g" else 0)

        with self.assertRaises(f005_mcu.SafetyError):
            self.run_transition(probe, write=True, runner=runner)

        self.assertEqual(probe.reset_count, 1)
        self.assertEqual(probe.calls, [True])
        self.assertEqual(
            [argv[3] for argv, check in calls],
            ["-c", "-g"])


if __name__ == "__main__":
    unittest.main()
