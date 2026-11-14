"""Wake the Roku channel with DIAL and play a Bilibili video.

Example: python scripts/push.py BV1xx411c7mD --roku-ip 192.168.1.177
"""

import argparse
import ipaddress
import os
import re
import time
import urllib.parse
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET


DIAL_NAME = "RokuBiliCast"
BVID = re.compile(r"BV[0-9A-Za-z]{10}")


def push(roku_ip: str, video: str) -> str:
    match = BVID.search(video)
    if not match:
        raise ValueError("Expected a BV video ID or a Bilibili URL containing one")
    ipaddress.IPv4Address(roku_ip)
    root = f"http://{roku_ip}:8060"
    with urllib.request.urlopen(root + "/dial/dd.xml", timeout=5) as response:
        application_url = response.headers.get("Application-URL", "").rstrip("/")
    if not application_url.startswith(root + "/dial"):
        raise RuntimeError("Roku did not advertise the expected DIAL service")
    endpoint = application_url + "/" + DIAL_NAME
    with urllib.request.urlopen(endpoint, timeout=5) as response:
        document = ET.fromstring(response.read())
    name = document.findtext("{urn:dial-multiscreen-org:schemas:dial}name")
    if name != DIAL_NAME:
        raise RuntimeError("DIAL channel is not installed on this Roku")
    payload = urllib.parse.urlencode({"contentId": match.group(), "mediaType": "movie"}).encode()
    request = urllib.request.Request(
        endpoint,
        data=payload,
        headers={"Content-Type": "text/plain; charset=utf-8"},
        method="POST",
    )
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                if response.status not in (200, 201):
                    raise RuntimeError(f"DIAL launch returned HTTP {response.status}")
            break
        except urllib.error.HTTPError as error:
            if error.code != 503 or attempt == 5:
                raise
            # Roku can briefly reject launches immediately after entering standby.
            time.sleep(2)
    return match.group()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", help="BV video ID or Bilibili video URL")
    parser.add_argument("--roku-ip", default=os.environ.get("ROKU_IP"), required=not os.environ.get("ROKU_IP"))
    arguments = parser.parse_args()
    try:
        bvid = push(arguments.roku_ip, arguments.video)
        print(f"Sent {bvid} to Roku through DIAL")
    except (OSError, RuntimeError, ValueError, ET.ParseError) as error:
        parser.exit(1, f"Push failed: {error}\n")
