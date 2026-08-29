#!/usr/bin/env python3
"""TEST-ONLY: feed one sanitized G-code file to a running Klippy PTY.

This reproduces the Phase-2 first-print transport only. It is not a production
print spooler, does not reconnect or resend, and aborts on the first error.
"""

import argparse
import fcntl
import hashlib
import os
import select
import signal
import sys
import termios
import time


stop_requested = False
SAFE_STOP_WRITE_TIMEOUT = 2.0


def log(message):
    print(time.strftime("%H:%M:%S"), message, flush=True)


def request_stop(signum, frame):
    del frame
    global stop_requested
    stop_requested = True
    log("STOP REQUESTED signal=%d" % signum)


class KlippySession:
    def __init__(self, port):
        self.fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        attrs = termios.tcgetattr(self.fd)
        attrs[0] = attrs[1] = attrs[3] = 0
        attrs[2] |= termios.CREAD | termios.CLOCAL
        attrs[6][termios.VMIN] = 0
        attrs[6][termios.VTIME] = 0
        termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
        self.rxbuf = bytearray()
        self._drain()

    def _drain(self):
        while select.select([self.fd], [], [], 0)[0]:
            try:
                if not os.read(self.fd, 4096):
                    break
            except BlockingIOError:
                break

    def _write(self, data, honor_stop=True):
        pos = 0
        while pos < len(data):
            if honor_stop and stop_requested:
                raise InterruptedError("stop requested")
            try:
                pos += os.write(self.fd, data[pos:])
            except BlockingIOError:
                select.select([], [self.fd], [], 0.5)

    def command(self, command, timeout):
        self._write((command + "\n").encode("utf-8"))
        deadline = time.monotonic() + timeout
        responses = []
        while True:
            if stop_requested:
                raise InterruptedError("stop requested")
            while b"\n" in self.rxbuf:
                raw, _, rest = self.rxbuf.partition(b"\n")
                self.rxbuf = bytearray(rest)
                text = raw.decode("utf-8", "replace").rstrip("\r").strip()
                if not text:
                    continue
                if text == "ok" or text.startswith("ok "):
                    return responses
                log("RX " + text)
                responses.append(text)
                if text.startswith("!! ") or "Printer is shutdown" in text:
                    raise RuntimeError("Klipper error for %r: %s" % (command, text))
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("timeout waiting for %r" % command)
            if not select.select([self.fd], [], [], min(0.5, remaining))[0]:
                continue
            chunk = os.read(self.fd, 4096)
            if not chunk:
                raise RuntimeError("Klipper PTY closed")
            self.rxbuf.extend(chunk)

    def safe_stop(self):
        log("SAFE STOP: heater/fan targets -> 0")
        payload = b"M104 S0\nM140 S0\nM106 S0\n"
        pos = 0
        deadline = time.monotonic() + SAFE_STOP_WRITE_TIMEOUT
        while pos < len(payload):
            if time.monotonic() >= deadline:
                log("SAFE STOP local write deadline expired")
                return
            try:
                written = os.write(self.fd, payload[pos:])
                if written <= 0:
                    log("SAFE STOP local write made no progress")
                    return
                pos += written
            except BlockingIOError:
                remaining = deadline - time.monotonic()
                if remaining > 0:
                    select.select([], [self.fd], [], min(0.1, remaining))
            except OSError as exc:
                log("SAFE STOP local write failed: %s" % exc)
                return
        log("SAFE STOP commands written to PTY")

    def close(self):
        os.close(self.fd)


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as src:
        for chunk in iter(lambda: src.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def command_timeout(command):
    if command.startswith(("M190 ", "M109 ", "BED_MESH_CALIBRATE")):
        return 900
    if command.startswith("G28"):
        return 180
    return 120


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, help="Klippy input PTY")
    parser.add_argument("--gcode", required=True)
    parser.add_argument("--sha256", required=True,
                        help="expected SHA-256 of the sanitized input")
    args = parser.parse_args()

    actual = sha256(args.gcode)
    log("GCODE SHA256 " + actual)
    if actual.lower() != args.sha256.lower():
        raise SystemExit("G-code SHA256 mismatch")

    with open(args.gcode, "r", encoding="utf-8", errors="replace") as src:
        lines = list(src)
    session = KlippySession(args.port)
    try:
        status = session.command("STATUS", 10)
        if not any("Klipper state: Ready" in line for line in status):
            raise RuntimeError("Klipper is not Ready")
        log("PREFLIGHT STATUS: PASS")
        sensor = session.command("QUERY_FILAMENT_SENSOR SENSOR=filament_sensor", 10)
        if not any("filament detected" in line for line in sensor):
            raise RuntimeError("filament sensor does not report filament")
        log("PREFLIGHT FILAMENT: PASS")
        log("PRINT START")
        count = 0
        for lineno, raw in enumerate(lines, 1):
            command = raw.strip()
            if not command or command.startswith(";"):
                continue
            count += 1
            if command.startswith(("G28", "BED_MESH_CALIBRATE", "M140 ",
                                   "M190 ", "M104 ", "M109 ")):
                log("LINE %d: %s" % (lineno, command[:180]))
            if count % 2000 == 0:
                log("PROGRESS %.1f%% line=%d commands=%d"
                    % (100.0 * lineno / len(lines), lineno, count))
            session.command(command, command_timeout(command))
        log("PRINT COMPLETE")
    except Exception as exc:
        log("PRINT ABORTED: %s" % exc)
        session.safe_stop()
        return 1
    finally:
        session.close()
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)
    sys.exit(main())
