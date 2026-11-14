"""Measure the installed Roku-only probe; no discovery server runs on this PC.

Default: one read-only sample. --exercise sends Home, launches the probe through
DIAL, then sends PowerOff and launches it again. Install the diagnostic ZIP first.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import ipaddress
import json
from pathlib import Path
import socket
import time
import urllib.error
import urllib.request
import uuid
import xml.etree.ElementTree as ET


def request(url, data=None, timeout=2):
    with urllib.request.urlopen(url, data=data, timeout=timeout) as response:
        return response.status, response.read()


def tcp_probe(ip, token):
    try:
        _, body = request(f"http://{ip}:9959/probe/{token}", timeout=0.7)
        result = json.loads(body)
        assert result["token"] == f"GET /probe/{token} HTTP/1.1"
        return {"ok": True, **result}
    except (OSError, ValueError, AssertionError) as error:
        return {"ok": False, "error": type(error).__name__}


def udp_probe(ip, token):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(0.7)
            message = "ROKU-LIFECYCLE " + token
            sock.sendto(message.encode("ascii"), (ip, 9959))
            body, peer = sock.recvfrom(2048)
        result = json.loads(body)
        assert peer == (ip, 9959) and result["token"] == message
        return {"ok": True, **result}
    except (OSError, ValueError, AssertionError) as error:
        return {"ok": False, "error": type(error).__name__}


def xml_query(ip, path):
    _, body = request(f"http://{ip}:8060{path}")
    return ET.fromstring(body)


def sample(ip, phase, started):
    token = uuid.uuid4().hex
    elapsed = round(time.monotonic() - started, 3)
    with ThreadPoolExecutor(max_workers=2) as pool:
        tcp = pool.submit(tcp_probe, ip, token)
        udp = pool.submit(udp_probe, ip, token)
        result = {"phase": phase, "elapsed": elapsed, "tcp": tcp.result(), "udp": udp.result()}
    active = xml_query(ip, "/query/active-app")
    app = active.find("app")
    result["active_app"] = None if app is None else app.get("id")
    result["power"] = xml_query(ip, "/query/device-info").findtext("power-mode")
    result["dial_state"] = xml_query(ip, "/dial/RokuLifecycleProbe").findtext(
        "{urn:dial-multiscreen-org:schemas:dial}state"
    )
    print(json.dumps(result), flush=True)
    return result


def launch(ip):
    for attempt in range(6):
        try:
            request(f"http://{ip}:8060/dial/RokuLifecycleProbe", data=b"probe=1", timeout=8)
            break
        except urllib.error.HTTPError as error:
            if error.code != 503 or attempt == 5:
                raise
            time.sleep(1)
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        if tcp_probe(ip, uuid.uuid4().hex)["ok"]:
            return
        time.sleep(0.4)
    raise RuntimeError("Diagnostic channel did not respond after DIAL launch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ip", required=True, type=ipaddress.IPv4Address)
    parser.add_argument("--exercise", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    ip = str(args.ip)
    results = []
    active = xml_query(ip, "/query/active-app").find("app")
    if active is None or active.text != "Roku network lifecycle probe":
        raise SystemExit("Install and open the diagnostic channel before measuring.")
    try:
        results.append(sample(ip, "foreground", time.monotonic()))
        if not results[-1]["tcp"]["ok"] or not results[-1]["udp"]["ok"]:
            raise RuntimeError("Foreground control failed; do not interpret suspension results.")
        if args.exercise:
            for key, phase in [("Home", "home"), ("PowerOff", "standby")]:
                request(f"http://{ip}:8060/keypress/{key}", data=b"", timeout=15)
                started = time.monotonic()
                for offset in (0, 1, 3, 6, 10, 20, 35):
                    time.sleep(max(0, started + offset - time.monotonic()))
                    results.append(sample(ip, phase, started))
                launch(ip)
                results.append(sample(ip, phase + "-relaunched", time.monotonic()))
    finally:
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(results, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
