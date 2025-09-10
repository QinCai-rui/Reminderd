#!/usr/bin/env python3
"""client to talk to reminderd via Unix socket."""
# Code quality sucks. 
import os
import sys
import socket
from pathlib import Path

# store here so don't need root
SOCKET_PATH = os.environ.get("REMINDERD_SOCKET", str(Path.home() / ".local" / "share" / "reminderd" / "reminderd.sock"))


def send(cmd: str) -> str:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(SOCKET_PATH)
    except FileNotFoundError:
        print("reminderd socket not found; is the daemon running?", file=sys.stderr)
        sys.exit(2)
    s.sendall((cmd + "\n").encode())
    data = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        data += chunk
    return data.decode(errors="ignore").strip()


def usage():
    print("Usage: reminderctl add <epoch> <message>")   # TODO need better time like `at`/`atd`
    print("       reminderctl list")
    print("       reminderctl remove <id>")
    print("       reminderctl ping")


def main():
    """main entry point."""
    if len(sys.argv) < 2:
        usage(); sys.exit(1)
    cmd = sys.argv[1].lower()
    if cmd == 'add':
        if len(sys.argv) < 4:
            usage(); sys.exit(1)
        when = sys.argv[2]
        msg = ' '.join(sys.argv[3:])
        resp = send(f"ADD|{when}|{msg}")
        print(resp)
    elif cmd == 'list':
        resp = send("LIST")
        print(resp)
    elif cmd == 'remove':
        if len(sys.argv) < 3:
            usage(); sys.exit(1)
        rid = sys.argv[2]
        resp = send(f"REMOVE|{rid}")
        print(resp)
    elif cmd == 'ping':
        print(send("PING"))
    else:
        usage(); sys.exit(1)


if __name__ == '__main__':
    main()
