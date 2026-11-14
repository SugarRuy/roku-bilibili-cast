"""Print LAN SSDP search targets without recording packet bodies or account data.

Use while opening a phone's cast picker to learn which discovery service it asks
for. The computer must be on the same multicast-capable LAN as the phone.
"""

import argparse
import os
import socket
import struct
import time


GROUP = "239.255.255.250"


def local_address(peer: str) -> str:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.connect((peer, 8060))
        return sock.getsockname()[0]


def listen(peer: str, seconds: int) -> None:
    address = local_address(peer)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(("", 1900))
        membership = socket.inet_aton(GROUP) + socket.inet_aton(address)
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)
        sock.settimeout(0.5)
        print(f"Listening for SSDP M-SEARCH on {address}:1900 for {seconds}s", flush=True)
        seen: dict[tuple[str, str], float] = {}
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            try:
                packet, sender = sock.recvfrom(8192)
            except socket.timeout:
                continue
            lines = packet.decode("utf-8", "replace").splitlines()
            if not lines or not lines[0].upper().startswith("M-SEARCH "):
                continue
            headers = {}
            for line in lines[1:]:
                name, separator, value = line.partition(":")
                if separator:
                    headers[name.lower()] = value.strip()
            target = headers.get("st", "")[:160]
            if not target:
                continue
            key = (sender[0], target)
            now = time.monotonic()
            if now - seen.get(key, -100) < 2:
                continue
            seen[key] = now
            agent = headers.get("user-agent", "")[:100]
            print(f"source={sender[0]} st={target} ua={agent}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--roku-ip", default=os.environ.get("ROKU_IP", "192.168.1.177"))
    parser.add_argument("--seconds", type=int, default=180)
    args = parser.parse_args()
    listen(args.roku_ip, args.seconds)
