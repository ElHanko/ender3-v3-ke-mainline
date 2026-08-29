#!/usr/bin/env python3
"""Send one normal Klipper ``reset`` to a shutdown F005 MCU.

This is a Phase-2 reproduction helper, not a service or recovery tool. It
opens only /dev/ttyS1 once at 230400 and permits only identify, get_config,
and one dictionary reset. It never reconnects, retries the reset, uses modem
control, or sends config_reset/emergency_stop.
"""

import argparse
import errno
import fcntl
import os
import re
import sys
import termios
import time
import traceback


UART_PATH = "/dev/ttyS1"
UART_BAUD = 230400
MAX_IDENTIFY_BYTES = 1024 * 1024
RESET_QUEUE_DEADLINE_SECONDS = 0.010
RESET_QUEUE_POLL_SECONDS = 0.001
TIOCEXCL = 0x540C
IDENTIFY_RE = re.compile(r"\Aidentify offset=(0|[1-9][0-9]*) count=40\Z")
BYTES_WRITE_RE = re.compile(r"(?:^|\s)bytes_write=([0-9]+)(?:\s|$)")


class SafetyViolation(Exception):
    pass


class ResetGate:
    """Allow only the precise request sequence needed by this helper."""

    def __init__(self):
        self.approved_raw = None
        self.reset_sent = False

    def begin_query(self, message, response, encoded):
        identify = IDENTIFY_RE.fullmatch(message)
        if identify is not None and response == "identify_response":
            if int(identify.group(1)) > MAX_IDENTIFY_BYTES:
                raise SafetyViolation("identify offset exceeds safety limit")
        elif message == "get_config" and response == "config":
            pass
        else:
            raise SafetyViolation("blocked query command: %r" % (message,))
        if self.approved_raw is not None:
            raise SafetyViolation("nested transmit authorization")
        self.approved_raw = bytes(bytearray(encoded))

    def begin_reset(self, encoded):
        if self.reset_sent:
            raise SafetyViolation("second reset is blocked")
        if self.approved_raw is not None:
            raise SafetyViolation("nested transmit authorization")
        self.approved_raw = bytes(bytearray(encoded))

    def check_raw(self, encoded):
        raw = bytes(bytearray(encoded))
        if self.approved_raw is None or raw != self.approved_raw:
            raise SafetyViolation("blocked unauthorized raw MCU transmit")

    def end(self):
        self.approved_raw = None


class RawUart:
    """The validated direct termios attach; it does not touch RTS or DTR."""

    def __init__(self):
        self.fd = None

    def open(self):
        if self.fd is not None:
            raise SafetyViolation("UART already open")
        flags = os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK
        flags |= getattr(os, "O_CLOEXEC", 0)
        fd = os.open(UART_PATH, flags)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            try:
                fcntl.ioctl(fd, TIOCEXCL)
            except OSError as exc:
                if exc.errno != errno.ENOTTY:
                    raise
            attrs = termios.tcgetattr(fd)
            attrs[0] = attrs[1] = attrs[3] = 0
            attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
            attrs[4] = attrs[5] = termios.B230400
            attrs[6][termios.VMIN] = 0
            attrs[6][termios.VTIME] = 0
            termios.tcsetattr(fd, termios.TCSANOW, attrs)
        except Exception:
            os.close(fd)
            raise
        self.fd = fd
        return self

    def fileno(self):
        if self.fd is None:
            raise SafetyViolation("UART is closed")
        return self.fd

    def close(self):
        if self.fd is not None:
            fd, self.fd = self.fd, None
            os.close(fd)

    def __enter__(self):
        return self.open()

    def __exit__(self, exc_type, exc_value, traceback_value):
        self.close()


def make_reset_reader(serialhdl_module):
    base = serialhdl_module.SerialReader

    class ResetOnceSerialReader(base):
        def __init__(self, reactor_instance):
            base.__init__(self, reactor_instance, mcu_name="reset-once")
            self.reset_gate = ResetGate()
            self.identified = False
            self.config_checked = False

        def send(self, msg, minclock=0, reqclock=0):
            raise SafetyViolation("generic send() is disabled")

        def send_with_response(self, msg, response):
            encoded = self.msgparser.create_command(msg)
            self.reset_gate.begin_query(msg, response, encoded)
            try:
                retry = serialhdl_module.SerialRetryCommand(self, response)
                return retry.get_response([encoded], self.default_cmd_queue)
            finally:
                self.reset_gate.end()

        def raw_send(self, cmd, minclock, reqclock, cmd_queue):
            self.reset_gate.check_raw(cmd)
            return base.raw_send(self, cmd, minclock, reqclock, cmd_queue)

        def raw_send_wait_ack(self, cmd, minclock, reqclock, cmd_queue):
            self.reset_gate.check_raw(cmd)
            return base.raw_send_wait_ack(
                self, cmd, minclock, reqclock, cmd_queue)

        def connect_uart(self, *args, **kwargs):
            raise SafetyViolation("connect_uart() is disabled")

        def connect_pipe(self, *args, **kwargs):
            raise SafetyViolation("connect_pipe() is disabled")

        def connect_canbus(self, *args, **kwargs):
            raise SafetyViolation("CAN connection is disabled")

        def connect_file(self, *args, **kwargs):
            raise SafetyViolation("file connection is disabled")

        def identify_from_open_uart(self, serial_device):
            result = base._start_session(self, serial_device)
            self.identified = bool(result)
            return result

        def get_config_once(self):
            if not self.identified:
                raise SafetyViolation("get_config before identify is blocked")
            if self.config_checked:
                raise SafetyViolation("second get_config is blocked")
            result = self.send_with_response("get_config", "config")
            self.config_checked = True
            return result

        def reset_once(self):
            if not self.identified or not self.config_checked:
                raise SafetyViolation("reset before verified get_config")
            encoded = self.msgparser.create_command("reset")
            before = get_bytes_written(self)
            self.reset_gate.begin_reset(encoded)
            try:
                self.raw_send(encoded, 0, 0, self.default_cmd_queue)
                self.reset_gate.reset_sent = True
            finally:
                self.reset_gate.end()
            wait_for_serialqueue_write(self, before)

    return ResetOnceSerialReader


def get_bytes_written(reader):
    stats = reader.stats(reader.reactor.monotonic())
    match = BYTES_WRITE_RE.search(stats)
    if match is None:
        raise RuntimeError("serialqueue statistics lack bytes_write")
    return int(match.group(1))


def wait_for_serialqueue_write(reader, before):
    """Wait only until serialqueue's writer has submitted the reset."""
    deadline = reader.reactor.monotonic() + RESET_QUEUE_DEADLINE_SECONDS
    while reader.reactor.monotonic() < deadline:
        if get_bytes_written(reader) > before:
            return
        reader.reactor.pause(min(
            deadline, reader.reactor.monotonic() + RESET_QUEUE_POLL_SECONDS))
    raise RuntimeError("reset was queued but serialqueue write was not observed")


def log(message):
    sys.stdout.write("%s\n" % (message,))
    sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--klippy-dir", required=True,
                        help="pinned Mainline Klipper klippy directory")
    args = parser.parse_args()
    if not os.path.isdir(args.klippy_dir):
        raise SystemExit("invalid --klippy-dir")
    sys.path.insert(0, args.klippy_dir)
    import reactor
    import serialhdl

    reactor_instance = reactor.Reactor()
    result = {"error": None}
    reader_class = make_reset_reader(serialhdl)

    def run_reset(eventtime):
        reader = None
        uart = None
        try:
            uart = RawUart().open()
            reader = reader_class(reactor_instance)
            if not reader.identify_from_open_uart(uart):
                raise RuntimeError("identify session failed")
            log("IDENTIFY PASS")
            config = reader.get_config_once()
            is_config = int(config["is_config"])
            is_shutdown = int(config["is_shutdown"])
            log("PRE-RESET GET_CONFIG is_config=%d is_shutdown=%d"
                % (is_config, is_shutdown))
            if is_config != 1 or is_shutdown != 1:
                raise SafetyViolation(
                    "FAIL CLOSED: expected is_config=1 is_shutdown=1")
            reader.reset_once()
            log("RESET COMMAND SENT ONCE")
        except Exception:
            result["error"] = traceback.format_exc()
        finally:
            if reader is not None:
                reader.disconnect()
            if uart is not None:
                uart.close()
            reactor_instance.end()
        return reactor_instance.NEVER

    reactor_instance.register_callback(run_reset)
    try:
        reactor_instance.run()
    finally:
        reactor_instance.finalize()
    if result["error"] is not None:
        sys.stderr.write("RESET FAILED CLOSED:\n%s" % (result["error"],))
        return 1
    log("EXIT")
    return 0


if __name__ == "__main__":
    sys.exit(main())
