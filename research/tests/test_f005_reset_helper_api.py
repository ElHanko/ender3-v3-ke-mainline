#!/usr/bin/env python3
"""Check the reset helper against a pinned Klipper SerialReader API.

This test parses the supplied serialhdl.py and instantiates the helper's
derived reader with a signature-equivalent stand-in. It performs no UART I/O.
"""

import argparse
import ast
import importlib.util
from pathlib import Path
import sys


def serialreader_init_signature(path):
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in tree.body:
        if not isinstance(node, ast.ClassDef) or node.name != "SerialReader":
            continue
        for method in node.body:
            if isinstance(method, ast.FunctionDef) and method.name == "__init__":
                args = [arg.arg for arg in method.args.args]
                defaults = method.args.defaults
                return args, len(defaults)
    raise SystemExit("SerialReader.__init__ not found")


def load_helper(path):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("f005_reset_helper", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serialhdl", required=True, type=Path)
    args = parser.parse_args()
    names, default_count = serialreader_init_signature(args.serialhdl)
    expected = ["self", "reactor", "mcu_name"]
    if names != expected or default_count != 1:
        raise SystemExit("unsupported SerialReader.__init__ signature: %r" % names)

    class PinnedSerialReader:
        def __init__(self, reactor, mcu_name=""):
            self.reactor = reactor
            self.mcu_name = mcu_name

    serialhdl = type("SerialHdl", (), {"SerialReader": PinnedSerialReader})
    helper_path = (Path(__file__).parent.parent / "scripts" /
                   "f005_reset_from_shutdown_once.py")
    helper = load_helper(helper_path)
    reader = helper.make_reset_reader(serialhdl)(object())
    if reader.mcu_name != "reset-once":
        raise SystemExit("reset helper did not pass the pinned mcu_name API")
    print("reset-helper SerialReader API: PASS")


if __name__ == "__main__":
    main()
