#!/usr/bin/env python3
"""Run commands on the frame's U-Boot prompt over the USB ACM console.

    tools/ubcmd.py 'version' 'mmc info'
    tools/ubcmd.py --timeout 60 'ums 0 mmc 0'

Each command is sent once the "=> " prompt shows; its output is printed.
Standard library only (no pyserial).
"""
import argparse
import os
import select
import termios
import time

PROMPT = b"\n=> "  # at line start: crc32 prints "==> "


def open_tty(path):
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY)
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0                                    # iflag
    attrs[1] = 0                                    # oflag
    attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attrs[3] = 0                                    # lflag: raw, no echo
    attrs[4] = attrs[5] = termios.B115200
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    return fd


def read_until(fd, marker, timeout, contains=False):
    buf = b""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            buf += os.read(fd, 4096)
            if (marker in buf) if contains else buf.endswith(marker):
                return buf, True
    return buf, False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("commands", nargs="*")
    p.add_argument("--tty", default="/dev/ttyACM0")
    p.add_argument("--timeout", type=float, default=10)
    args = p.parse_args()

    fd = open_tty(args.tty)
    read_until(fd, b"\0never", 0.5)                 # drain leftovers from earlier sessions
    os.write(fd, b"\r")
    _, ok = read_until(fd, PROMPT, 3)
    if not ok:
        raise SystemExit("no U-Boot prompt on " + args.tty)
    for cmd in args.commands:
        os.write(fd, cmd.encode() + b"\r")
        out, ok = read_until(fd, PROMPT, args.timeout)
        text = out.decode(errors="replace").replace("\r", "")
        # drop the echoed command line and the trailing prompt
        text = text.split("\n", 1)[1] if text.startswith(cmd) else text
        print(f"=> {cmd}\n{text.removesuffix('=> ').rstrip()}")
        if not ok:
            print(f"[no prompt after {args.timeout}s]")


if __name__ == "__main__":
    main()
