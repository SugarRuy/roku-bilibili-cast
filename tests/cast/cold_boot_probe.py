"""Observe a real Roku reboot without launching any channel.

GET requests and SSDP discovery only. The caller triggers the restart separately.
Records uptime resets, system DIAL state, receiver availability and M-SEARCH
targets, not video URLs, credentials or packet bodies. This is a finite diagnostic
client, not a casting bridge. It cannot observe phone-to-TV unicast traffic.
"""

import argparse
import concurrent.futures
import datetime
import json
from pathlib import Path
import socket
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET


def get(ip, port, path):
    try:
        with urllib.request.urlopen(f"http://{ip}:{port}{path}", timeout=1.5) as reply:
            return reply.status, reply.read()
    except urllib.error.HTTPError as exc:
        return exc.code, b""
    except (OSError, urllib.error.URLError):
        return None, b""


def sample(ip, pool):
    paths = {
        "device": (8060, "/query/device-info"),
        "active": (8060, "/query/active-app"),
        "dial": (8060, "/dial/RokuBiliCast"),
        "receiver": (9958, "/status"),
    }
    jobs = {key: pool.submit(get, ip, *path) for key, path in paths.items()}
    result = {"at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    for key, job in jobs.items():
        status, body = job.result()
        result[key] = {"http": status}
        if status != 200:
            continue
        try:
            if key == "receiver":
                state = json.loads(body)
                result[key].update({
                    k: state.get(k) for k in
                    ("suspended", "ssdpbound", "multicastjoined", "pending")
                })
            else:
                node = ET.fromstring(body)
                if key == "device":
                    result[key].update({
                        "uptime": int(node.findtext("uptime")),
                        "power": node.findtext("power-mode"),
                    })
                elif key == "active":
                    app = node.find("app")
                    result[key]["id"] = app.get("id") if app is not None else None
                else:
                    result[key]["state"] = next(
                        (n.text for n in node.iter() if n.tag.split("}")[-1] == "state"),
                        None,
                    )
        except (ValueError, TypeError, ET.ParseError):
            result[key]["parse_error"] = True
    return result


def open_listener(ip):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((ip, 8060))
        address = route.getsockname()[0]
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(("", 1900))
        sock.setsockopt(
            socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP,
            socket.inet_aton("239.255.255.250") + socket.inet_aton(address),
        )
        sock.setblocking(False)
        return sock
    except Exception:
        sock.close()
        raise


def drain_searches(sock):
    searches = []
    while True:
        try:
            packet, sender = sock.recvfrom(8192)
        except BlockingIOError:
            return searches
        lines = packet.decode("utf-8", "replace").splitlines()
        if not lines or not lines[0].upper().startswith("M-SEARCH "):
            continue
        headers = {}
        for line in lines[1:]:
            name, sep, value = line.partition(":")
            if sep:
                headers[name.strip().lower()] = value.strip()
        searches.append({
            "source": sender[0], "st": headers.get("st", "")[:160],
            "agent": headers.get("user-agent", "")[:100],
        })


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ip", required=True)
    parser.add_argument("--seconds", type=int, default=180)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 600:
        parser.error("--seconds must be between 1 and 600")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "diagnostic_only": True, "launch_requests_sent": 0,
        "samples": [], "searches": [], "uptime_reset_observed": False,
    }
    listener = None
    try:
        listener = open_listener(args.ip)
    except OSError as exc:
        report["discovery_capture_error"] = type(exc).__name__
    baseline_uptime = None
    previous = None
    deadline = time.monotonic() + args.seconds
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            while time.monotonic() < deadline:
                current = sample(args.ip, pool)
                uptime = current["device"].get("uptime")
                if baseline_uptime is None and uptime is not None:
                    baseline_uptime = uptime
                if uptime is not None and baseline_uptime is not None and uptime < baseline_uptime:
                    report["uptime_reset_observed"] = True
                report["samples"].append(current)
                if listener:
                    for search in drain_searches(listener):
                        search["at"] = current["at"]
                        report["searches"].append(search)
                signature = (
                    current["device"].get("power"), current["active"].get("id"),
                    current["dial"].get("state"), current["receiver"].get("http"),
                    report["uptime_reset_observed"],
                )
                if signature != previous:
                    print(json.dumps(current, ensure_ascii=False), flush=True)
                    previous = signature
                args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
                time.sleep(1)
    finally:
        if listener:
            listener.close()
        args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({
        "output": str(args.output),
        "uptime_reset_observed": report["uptime_reset_observed"],
        "samples": len(report["samples"]),
        "searches": len(report["searches"]),
    }), flush=True)


if __name__ == "__main__":
    main()
