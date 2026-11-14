"""Exercise a focused four-column Roku video grid and record pagination/focus.

Run only when TV control is authorized and a video grid has focus. This sends
remote keys; it does not install or launch an app. ECP response times are NOT
frame times and cannot prove that a scroll animation is visually smooth.

python tests/ui/grid_scroll_probe.py --ip 192.168.1.177 --output build/grid-probe
"""
import argparse
import json
import time
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ip", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    base = f"http://{args.ip}:8060"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def snapshot():
        begin = time.monotonic()
        with opener.open(base + "/query/app-ui", timeout=10) as response:
            body = response.read()
        root = ET.fromstring(body)
        grids = [
            node for node in root.iter("MarkupGrid")
            if node.get("focused") == "true"
        ]
        if len(grids) != 1:
            raise RuntimeError("Expected one focused MarkupGrid; stopped sending keys")
        grid = grids[0]
        return body, {
            "count": int(grid.get("count", "0")),
            "focus": int(grid.get("focusItem", "-1")),
            "ecp_ms": round((time.monotonic() - begin) * 1000),
        }

    body, previous = snapshot()
    if previous["focus"] < 0 or previous["count"] < 20:
        raise RuntimeError("Focus a populated four-column video grid first")
    records = [{"key": "initial", **previous}]
    args.output.joinpath("initial.xml").write_bytes(body)
    # Fresh rows and page boundaries, followed by the same cached rows.
    keys = ["Down"] * 12 + ["Up"] * 4 + ["Down"] * 4
    for step, key in enumerate(keys, 1):
        request = urllib.request.Request(base + "/keypress/" + key, data=b"")
        with opener.open(request, timeout=5):
            pass
        time.sleep(0.6)
        body, current = snapshot()
        expected = previous["focus"] + (4 if key == "Down" else -4)
        current["focus_ok"] = current["focus"] == expected
        current["count_ok"] = current["count"] >= previous["count"]
        records.append({"step": step, "key": key, **current})
        if not current["focus_ok"] or not current["count_ok"]:
            args.output.joinpath(f"unexpected-{step}.xml").write_bytes(body)
            # Do not keep driving a changed screen or a finite list boundary.
            break
        previous = current
    args.output.joinpath("final.xml").write_bytes(body)
    args.output.joinpath("results.json").write_text(
        json.dumps(records, indent=2), encoding="utf-8"
    )
    passed = len(records) == len(keys) + 1 and all(
        row.get("focus_ok", True) and row.get("count_ok", True) for row in records
    )
    print(json.dumps({"passed": passed, "steps": len(records) - 1,
                      "initial": records[0], "final": records[-1]}))
    if not passed:
        raise SystemExit("Grid focus/pagination regression or list ended; inspect results")


if __name__ == "__main__":
    main()
