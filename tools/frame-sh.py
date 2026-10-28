#!/usr/bin/env python3
"""Run shell commands on the frame's Linux console over USB ACM.

    tools/frame-sh.py 'uname -a' 'dmesg | tail'

Each command's output is delimited with an echoed marker, so no prompt
matching is needed. Standard library only.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ubcmd import open_tty, read_until  # noqa: E402


def main():
    p = argparse.ArgumentParser()
    p.add_argument("commands", nargs="+")
    p.add_argument("--tty", default="/dev/ttyACM0")
    p.add_argument("--timeout", type=float, default=15)
    args = p.parse_args()

    fd = open_tty(args.tty)
    read_until(fd, b"\0never", 0.3)                 # drain
    os.write(fd, b"stty -echo 2>/dev/null; PS1=''\n")
    read_until(fd, b"\0never", 0.5)
    for i, cmd in enumerate(args.commands):
        marker = f"__frame_sh_done_{i}__"
        # Marker on its own line: a command may end in "&".
        os.write(fd, f"{cmd}\necho; echo {marker} $?\n".encode())
        out, ok = read_until(fd, f"{marker} ".encode(), args.timeout, contains=True)
        text = out.decode(errors="replace").replace("\r", "")
        text, _, rest = text.partition(f"{marker} ")
        if ok and "\n" not in rest:
            rest += read_until(fd, b"\n", 2, contains=True)[0].decode(errors="replace")
        text = text.rstrip("\n")
        status = rest.strip()
        print(f"$ {cmd}" + ("" if status in ("0", "") else f"   [exit {status}]"))
        print(text if ok else text + f"\n[timed out after {args.timeout}s]")


if __name__ == "__main__":
    main()
