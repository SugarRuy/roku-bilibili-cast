"""Real Roku regression for rapid Play/Stop while a lookup is in flight.

Changes the TV's playback. Ends on the requested recovery video.
Input contains video identifiers only; no phone or TV account credentials.
"""
import argparse
import json
from pathlib import Path
import select
import socket
import struct
import time
import urllib.request
import xml.etree.ElementTree as ET

from network_probe import command, receive_frame, session
from device_config import roku_ip


class Client:
    def __init__(self, ip):
        self.ip = ip
        self.sock = session(ip)
        self.sequence = 3000
        self.pending = set()
        self.notices = []

    def send(self, action, data=None):
        self.sequence += 1
        self.pending.add(self.sequence)
        self.sock.sendall(command(action, data, self.sequence))

    def pump(self, seconds=0.1):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if not select.select([self.sock], [], [], min(0.05, max(0, deadline - time.monotonic())))[0]:
                continue
            kind, sequence, action, data = receive_frame(self.sock)
            if kind == 0xE4:
                self.sock.sendall(b"\xc0\x00" + struct.pack(">I", sequence))
            elif kind == 0xC0:
                assert sequence in self.pending, ("unexpected ACK", sequence)
                self.pending.remove(sequence)
            elif kind == 0xE0:
                self.notices.append((action, data))

    def status(self):
        with urllib.request.urlopen(f"http://{self.ip}:9958/status", timeout=2) as response:
            return json.load(response)

    def wait(self, predicate, seconds=40):
        deadline = time.monotonic() + seconds
        status = {}
        while time.monotonic() < deadline:
            self.pump(0.35)
            status = self.status()
            if predicate(status):
                return status
            if status.get("pipeline", {}).get("stage") in ("lookup-error", "no-parts", "lookup-timeout"):
                raise AssertionError(("lookup did not succeed", status["pipeline"]))
        raise AssertionError(("timed out", status.get("pipeline"), status.get("playback")))

    def wait_playing(self, generation):
        status = self.wait(
            lambda s: s.get("pipeline", {}).get("generation") == generation
            and s["pipeline"]["stage"] == "playing"
            and s["playback"].get("generation") == generation
            and s["playback"]["state"] == 4
        )
        self.pump(1.2)
        assert not self.pending, ("unanswered commands", self.pending)
        assert any(action == "PLAY_SUCCESS" for action, _ in self.notices), "missing playback success notification"
        with urllib.request.urlopen(f"http://{self.ip}:8060/query/media-player", timeout=3) as response:
            player = ET.fromstring(response.read())
        assert player.get("state") == "play" and player.get("error") == "false", player.attrib
        return status["pipeline"]


def run(ip, recovery_file, output):
    recovery = json.loads(recovery_file.read_text(encoding="utf-8"))
    payload = {key: value for key, value in recovery.items() if key in ("aid", "bvid", "cid") and value}
    assert payload.get("aid") or payload.get("bvid"), "Recovery input requires a video ID"
    payload["seekTs"] = recovery.get("position") or 0
    # Reuse the user's known accessible video. The regression concerns request
    # generations and player replacement; unrelated public fixtures may be gone.
    alternate = dict(payload)
    alternate["seekTs"] = 1
    results = []
    completed = False
    recovery_after_failure = None
    client = Client(ip)
    try:
        base = (client.status().get("pipeline") or {}).get("generation", 0)
        for i in range(6):
            client.send("Play", alternate if i % 2 == 0 else payload)
            client.pump(0.06)
        pipeline = client.wait_playing(base + 6)
        results.append({"case": "six_rapid_requests_latest_wins", "pipeline": pipeline})
        print("PASS six rapid requests: latest video playing", pipeline, flush=True)

        base = pipeline["generation"]
        client.send("Play", alternate)
        client.pump(0.06)
        client.send("Stop")
        status = client.wait(lambda s: s.get("pipeline", {}).get("generation") == base + 2
                             and s["pipeline"]["stage"] == "stopped"
                             and s["playback"]["state"] == 7, seconds=8)
        # Allow a cancelled HTTP request to finish; it must not resurrect playback.
        client.pump(2)
        after = client.status()
        assert after["pipeline"]["generation"] == base + 2 and after["pipeline"]["stage"] == "stopped"
        assert after["playback"]["state"] == 7
        assert not client.pending
        results.append({"case": "stop_during_lookup_no_late_playback", "pipeline": status["pipeline"]})
        print("PASS stop during lookup: remains stopped", flush=True)

        client.notices.clear()
        client.send("Play", alternate)
        pipeline = client.wait_playing(base + 3)
        results.append({"case": "play_after_cancel_starts", "pipeline": pipeline})
        print("PASS play after cancel starts", pipeline, flush=True)

        client.notices.clear()
        client.send("Play", payload)
        pipeline = client.wait_playing(base + 4)
        results.append({"case": "replace_active_player_restore_requested_video", "pipeline": pipeline})
        print("PASS restored requested video", pipeline, flush=True)
        completed = True
    finally:
        if not completed:
            try:
                current = (client.status().get("pipeline") or {}).get("generation", 0)
                client.notices.clear()
                client.send("Play", payload)
                recovery_after_failure = client.wait_playing(current + 1)
                print("Restored requested video after failed test", flush=True)
            except Exception as error:
                recovery_after_failure = {"failed": type(error).__name__}
                print("Automatic recovery did not complete:", type(error).__name__, flush=True)
        client.sock.close()
        output.write_text(json.dumps({
            "completed": completed, "tests": results, "recovery_after_failure": recovery_after_failure,
        }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ip", help="Roku IPv4 address; otherwise read ROKU_IP or .env.local")
    parser.add_argument("--recovery", type=Path, default=Path(__file__).with_name("recovery.local.json"))
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("switch-regression-results.json"))
    args = parser.parse_args()
    run(args.ip or roku_ip(), args.recovery, args.output)
