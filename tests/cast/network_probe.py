"""Exercise the actual receiver on Roku: HTTP, SSDP, fragmented NVA and bounds.

Does not start a video or change account data.
"""
import argparse
import json
import socket
import struct
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET

from device_config import roku_ip

sys.stdout.reconfigure(encoding="utf-8")


def command(action, payload=None, sequence=41):
    action = action.encode("ascii")
    count = 2 if payload is None else 3
    header = bytes([0xE0, count]) + struct.pack(">I", sequence)
    # Canonical marker in the Macast NVA implementation (not Swift's reverse scan).
    header += b"\x01\x07Command" + bytes([len(action)]) + action
    if payload is not None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        header += struct.pack(">I", len(body)) + body
    return header


def receive_frame(sock):
    def take(size):
        data = bytearray()
        while len(data) < size:
            part = sock.recv(size - len(data))
            if not part:
                raise EOFError("receiver closed the connection")
            data.extend(part)
        return bytes(data)

    kind, count, sequence = struct.unpack(">BBI", take(6))
    if count == 0:
        return kind, sequence, "", None
    if kind in (0xC0, 0xC4):
        length = struct.unpack(">I", take(4))[0]
        assert length <= 65536
        return kind, sequence, "", json.loads(take(length))
    assert kind == 0xE0 and count in (2, 3)
    assert take(1) == b"\x01"
    take(take(1)[0])
    action = take(take(1)[0]).decode("ascii")
    body = None
    if count == 3:
        length = struct.unpack(">I", take(4))[0]
        assert length <= 65536
        body = json.loads(take(length))
    return kind, sequence, action, body


def session(ip):
    sock = socket.create_connection((ip, 9958), timeout=4)
    sock.settimeout(4)
    sock.sendall(b"SETUP /projection NVA/1.0\r\nSession: local-protocol-test\r\n\r\n")
    head = bytearray()
    while not head.endswith(b"\r\n\r\n"):
        head.extend(sock.recv(1))
        assert len(head) < 16384
    assert head.startswith(b"NVA 200 OK\r\n"), bytes(head)
    return sock


def wait_reply(sock, sequence):
    for _ in range(12):
        result = receive_frame(sock)
        if result[0] == 0xE4:
            sock.sendall(bytes([0xC0, 0]) + struct.pack(">I", result[1]))
        if result[0] == 0xC0:
            assert result[1] == sequence, ("wrong response sequence", result[1], sequence)
            return result[3]
    raise AssertionError("no reply; only unsolicited notifications")


def probe(ip):
    base = f"http://{ip}:9958"
    with urllib.request.urlopen(base + "/description.xml", timeout=4) as response:
        document = ET.fromstring(response.read())
    ns = {"d": "urn:schemas-upnp-org:device-1-0"}
    name = document.findtext("d:device/d:friendlyName", namespaces=ns)
    services = [element.text for element in document.findall(".//d:serviceType", ns)]
    assert "urn:app-bilibili-com:service:NirvanaControl:3" in services
    print("PASS HTTP device description:", name, flush=True)

    service = "urn:app-bilibili-com:service:NirvanaControl:3"
    envelope = (
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
        f'<s:Body><u:GetAppInfo xmlns:u="{service}"/></s:Body></s:Envelope>'
    ).encode()
    request = urllib.request.Request(
        base + "/NirvanaControl/action",
        data=envelope,
        headers={"Content-Type": "text/xml; charset=utf-8", "SOAPAction": f'"{service}#GetAppInfo"'},
    )
    with urllib.request.urlopen(request, timeout=4) as response:
        root = ET.fromstring(response.read())
    app_info = root.find(f".//{{{service}}}GetAppInfoResponse")
    assert app_info is not None
    assert {element.tag for element in app_info} == {"PackageName", "AppKey", "Signature", "CurrentSignedIn"}
    assert app_info.findtext("PackageName") == "com.xiaodianshi.tv.yst"
    assert app_info.findtext("CurrentSignedIn") in ("0", "1")
    print("PASS NVA GetAppInfo SOAP discovery check", flush=True)

    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    route = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    route.connect((ip, 1900))
    local_ip = route.getsockname()[0]
    route.close()
    udp.bind((local_ip, 0))
    udp.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(local_ip))
    udp.settimeout(3)
    request = (
        'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\nMX: 1\r\n'
        'ST: urn:app-bilibili-com:service:NirvanaControl:3\r\n\r\n'
    ).encode()
    udp.sendto(request, ("239.255.255.250", 1900))
    found = False
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        try:
            data, peer = udp.recvfrom(8192)
        except socket.timeout:
            break
        if peer[0] == ip and b"NirvanaControl:3" in data and b":9958/" in data:
            found = True
            break
    udp.close()
    assert found, "SSDP multicast response not received on the routed LAN interface"
    print("PASS SSDP multicast response", flush=True)

    with session(ip) as sock:
        packet = command("GetPlayState", sequence=41)
        # Split the six-byte frame prefix and command marker across TCP writes.
        for start, end in [(0, 1), (1, 4), (4, 8), (8, len(packet))]:
            sock.sendall(packet[start:end])
            time.sleep(0.08)
        result = wait_reply(sock, 41)
        assert "playState" in result, result
        print("PASS fragmented NVA request:", result, flush=True)
        sock.sendall(command("GetProgress", sequence=43) + command("GetPlayState", sequence=44))
        replies = [wait_reply(sock, 43), wait_reply(sock, 44)]
        assert any("duration" in item and "position" in item for item in replies)
        assert any("playState" in item for item in replies)
        print("PASS two NVA requests in one TCP write", flush=True)

    with session(ip) as sock:
        oversized = b"\xe0\x03" + struct.pack(">I", 100) + b"\x01\x07Command\x04Play" + struct.pack(">I", 65537)
        sock.sendall(oversized)
        try:
            for _ in range(10):
                receive_frame(sock)
        except (EOFError, ConnectionResetError):
            print("PASS oversized NVA payload rejected", flush=True)
        else:
            raise AssertionError("oversized payload was not rejected")
    with urllib.request.urlopen(base + "/status", timeout=4) as response:
        status = json.load(response)
    print("Receiver remained responsive; discovery status:", {
        key: status[key] for key in ("ssdpbound", "multicastjoined", "clients")
    }, flush=True)
    print("Scope: protocol checks only; phone UI discovery and visible playback need separate evidence.", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ip", help="Roku IPv4 address; otherwise read ROKU_IP or .env.local")
    args = parser.parse_args()
    probe(args.ip or roku_ip())
