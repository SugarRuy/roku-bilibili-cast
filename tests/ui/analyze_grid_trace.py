"""Analyze the final Down x10 / Up x10 / Down x10 sequence in a local trace.

Uses Roku native render events; does not infer frame times from ECP latency.
Install perfetto in the Python environment. No TV control or trace uploads.
"""
import json
import sys
from pathlib import Path
from perfetto.trace_processor import TraceProcessor

if len(sys.argv) != 2:
    raise SystemExit("usage: analyze_grid_trace.py <directory containing render.trace>")
folder = Path(sys.argv[1])
with TraceProcessor(trace=str(folder / "render.trace")) as tp:
    keys = list(tp.query("""
        select ts, extract_arg(arg_set_id,'debug.key') key from slice
        where name='keyEvent' and extract_arg(arg_set_id,'debug.isKeyPress')=1
        order by ts
    """))[-30:]
    assert [k.key for k in keys] == ["down"] * 10 + ["up"] * 10 + ["down"] * 10
    result = {}
    for phase, phase_keys in zip(
        ["cold_down", "warm_up", "warm_down"],
        [keys[:10], keys[10:20], keys[20:30]],
    ):
        rows = []
        for n, key in enumerate(phase_keys):
            renders = list(tp.query(f"""
                select ts,dur from slice where name='render'
                and ts between {key.ts} and {key.ts+350000000} order by ts
            """))
            gaps = [(b.ts-a.ts)/1e6 for a,b in zip(renders,renders[1:])]
            rows.append({
                "n": n, "frames": len(renders),
                "max_render_ms": round(max([r.dur/1e6 for r in renders],default=0),2),
                "max_gap_ms": round(max(gaps,default=0),2),
            })
        result[phase] = rows
        print(phase, "frames", [r["frames"] for r in rows],
              "max gaps", [r["max_gap_ms"] for r in rows],
              "max render", max(r["max_render_ms"] for r in rows))
    (folder / "analysis.json").write_text(json.dumps(result,indent=2))
