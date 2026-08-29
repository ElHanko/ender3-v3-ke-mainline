#!/usr/bin/env python3
"""Remove Stage-F-unsupported slicer commands from a G-code text file.

This is a test-only compatibility filter for the documented Phase-2 F005
first-print reproduction. It does not modify motion or thermal commands.
"""

import argparse
import re
from pathlib import Path


DROP_COMMAND = re.compile(
    r"^(EXCLUDE_OBJECT_DEFINE|EXCLUDE_OBJECT_START|EXCLUDE_OBJECT_END|M73)(?:\s|$)",
    re.IGNORECASE)
PRINTER_PARAM = re.compile(
    r"^SET_GCODE_VARIABLE\b.*\bMACRO=PRINTER_PARAM\b", re.IGNORECASE)
ACCEL_TO_DECEL = re.compile(
    r"^SET_VELOCITY_LIMIT\b.*\bACCEL_TO_DECEL=", re.IGNORECASE)
ALLOWED_COMMANDS = frozenset((
    "BED_MESH_CALIBRATE", "G1", "G21", "G28", "G90", "G92", "M104",
    "M106", "M109", "M140", "M190", "M220", "M221", "M83", "M84",
    "SET_VELOCITY_LIMIT",
))


def should_drop(line):
    command = line.split(";", 1)[0].lstrip()
    if DROP_COMMAND.match(command):
        return True
    return bool(PRINTER_PARAM.match(command) or ACCEL_TO_DECEL.match(command))


def command_type(line):
    command = line.split(";", 1)[0].strip()
    if not command:
        return None
    return command.split(None, 1)[0].upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error("input and output must differ")

    kept = []
    removed = 0
    with args.input.open("r", encoding="utf-8", errors="surrogateescape") as src:
        for lineno, line in enumerate(src, 1):
            if should_drop(line):
                removed += 1
                continue
            kind = command_type(line)
            if kind is not None and kind not in ALLOWED_COMMANDS:
                raise SystemExit(
                    "unsupported Stage-F command %s at line %d" %
                    (kind, lineno))
            kept.append(line)
    with args.output.open("w", encoding="utf-8", errors="surrogateescape") as dst:
        dst.writelines(kept)
    print("kept=%d removed=%d" % (len(kept), removed))


if __name__ == "__main__":
    main()
