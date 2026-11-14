"""Exercise the experimental Roku-only wake receiver with synthetic phone NVA.

Changes TV power, active app and playback. The test sets up Home/standby/another
app, but sends no DIAL or ECP launch to the Bilibili channel. Only a valid NVA
Play at the receiver's port 9958 may wake it. No bridge runs on the test computer.
Phone UI discovery still needs a separate real-phone acceptance check.
"""

import argparse
import json
from pathlib import Path
import struct
import time
import urllib.request
import xml.etree.ElementTree as ET

from device_config import roku_ip
from network_probe import command, probe, receive_frame, session


def wait_ack(sock, sequence):
    # Playback produces progress notices while this client polls ECP. A fixed
    # frame count mistakes the resulting backlog for a missing command ACK.
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        kind, reply_sequence, _, data = receive_frame(sock)
        if kind == 0xE4:
            sock.sendall(b"\xc0\x00" + struct.pack(">I", reply_sequence))
        if kind == 0xC0 and reply_sequence == sequence:
            return data
    raise TimeoutError(f"No acknowledgement for command {sequence}")


def request(ip, path, post=False):
    with urllib.request.urlopen(
        f"http://{ip}:8060{path}", data=b"" if post else None, timeout=15
    ) as response:
        return response.read()


def active(ip):
    node = ET.fromstring(request(ip, "/query/active-app")).find("app")
    return None if node is None else node.get("id")


def power(ip):
    return ET.fromstring(request(ip, "/query/device-info")).findtext("power-mode")


def status(ip):
    with urllib.request.urlopen(f"http://{ip}:9958/status", timeout=3) as response:
        return json.load(response)


def wait_player(ip, expected):
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        state = ET.fromstring(request(ip, "/query/media-player")).get("state")
        if state == expected:
            return
        time.sleep(0.15)
    raise AssertionError(f"Expected player state {expected}, got {state}")


def run_case(ip, case, bvid, idle_seconds, other_app):
    if active(ip) != "dev":
        raise RuntimeError("Open the experimental Bilibili channel before this case")
    if case == "other-app":
        if other_app == "dev" or not other_app.isdecimal():
            raise ValueError("--other-app must name another installed numeric app ID")
        request(ip, f"/launch/{other_app}", post=True)
    else:
        request(ip, "/keypress/" + ("PowerOff" if case == "standby" else "Home"), post=True)
    print(f"Waiting {idle_seconds}s in {case}; no receiver traffic during this interval.", flush=True)
    time.sleep(idle_seconds)
    before = {"active": active(ip), "power": power(ip)}
    expected = other_app if case == "other-app" else None
    assert before["active"] != "dev", before
    if expected:
        assert before["active"] == expected, before
    if case == "standby":
        assert before["power"] == "Ready", before
    assert status(ip)["suspended"] is True

    # Includes multicast SSDP, descriptions, GetAppInfo and NVA state queries.
    # None of these requests is allowed to launch the channel.
    probe(ip)
    assert {"active": active(ip), "power": power(ip)} == before, "Discovery woke the TV"
    old_generation = status(ip).get("pipeline", {}).get("generation", 0)
    started = time.monotonic()
    with session(ip) as sock:
        sock.sendall(command("Play", {"bvid": bvid, "seekTs": 0}, sequence=8101))
        wait_ack(sock, 8101)
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            current = status(ip)
            player = ET.fromstring(request(ip, "/query/media-player"))
            pipeline = current.get("pipeline", {})
            plugin = player.find("plugin")
            if (pipeline.get("stage") == "playing"
                    and pipeline.get("generation", 0) > old_generation
                    and current.get("playback", {}).get("generation") == pipeline["generation"]
                    and player.get("state") == "play" and plugin is not None
                    and plugin.get("id") == "dev"):
                assert active(ip) == "dev" and power(ip) == "PowerOn"
                assert current["suspended"] is False
                wakes = [event for event in current["events"] if event["kind"] == "self-wake"]
                assert any(event["detail"] in ("DIAL status=200", "DIAL status=201") for event in wakes)
                result = {
                    "case": case, "idle_seconds": idle_seconds, "before": before,
                    "seconds_to_playing": round(time.monotonic() - started, 3),
                    "pipeline": current["pipeline"], "playback": current["playback"],
                    "wake_events": wakes,
                    "phone_ui_verified": False,
                }
                sock.sendall(command("Pause", sequence=8110))
                wait_ack(sock, 8110)
                wait_player(ip, "pause")
                sock.sendall(command("Resume", sequence=8111))
                wait_ack(sock, 8111)
                wait_player(ip, "play")
                sock.sendall(command("Stop", sequence=8102))
                wait_ack(sock, 8102)
                deadline = time.monotonic() + 6
                while time.monotonic() < deadline and status(ip)["playback"]["state"] != 7:
                    time.sleep(0.15)
                assert status(ip)["playback"]["state"] == 7
                result["pause_resume_stop"] = "passed"
                print(json.dumps(result), flush=True)
                return result
            time.sleep(0.5)
    raise RuntimeError(("Playback did not start", current.get("pipeline"), current.get("events")))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ip")
    parser.add_argument("--bvid", required=True, help="A public video the test may play")
    parser.add_argument("--case", choices=("home", "standby", "other-app"), required=True)
    parser.add_argument("--other-app", default="837", help="Installed app ID; 837 is YouTube")
    parser.add_argument("--idle-seconds", type=int, default=35)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    result = run_case(
        arguments.ip or roku_ip(), arguments.case, arguments.bvid,
        arguments.idle_seconds, arguments.other_app,
    )
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
