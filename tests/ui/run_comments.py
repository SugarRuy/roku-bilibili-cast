"""Run production BrightScript comment logic with synthetic API/SceneGraph doubles.

Install the pinned, test-only interpreter outside the channel:
  npm install --prefix build/comments-test-runtime --ignore-scripts brs@0.45.0
Run:
  python tests/ui/run_comments.py

This never connects to the TV or an account. It does not emulate rendering,
remote event propagation, the native ScrollableText widget, or video decoding.
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build/comments-tests"


def functions(path, names):
    text = ROOT.joinpath(path).read_text(encoding="utf-8")
    result = []
    for name in names:
        match = re.search(
            rf"(?ims)^(?:function|sub) {name}\(.*?^end (?:function|sub)\s*$",
            text,
        )
        if not match:
            raise ValueError(f"Missing production function {name} in {path}")
        result.append(match[0])
    return "\n".join(result)


def main():
    interpreter = ROOT / "build/comments-test-runtime/node_modules/brs/bin/cli.js"
    if not interpreter.is_file():
        raise SystemExit("Install brs@0.45.0 with the command in this file's docstring.")
    BUILD.mkdir(parents=True, exist_ok=True)
    helpers = functions("channel/components/common/utils.brs", ["isNil", "strOf", "intOf", "fmtTime"])
    seek_source = ROOT.joinpath("channel/components/screens/PlayerSeek.brs").read_text(encoding="utf-8")
    assertion = """
sub check(passed as Boolean, label as String)
    if not passed then
        print "FAIL: " + label
        stop
    end if
    m.checks = m.checks + 1
end sub
"""
    suites = {
        "comments_api": (
            ROOT.joinpath("channel/components/bili/comments.brs").read_text(encoding="utf-8")
            + functions("channel/components/bili/text.brs", ["firstOf", "fmtCount"])
            + functions("channel/components/bili/ops.brs", ["okWith", "fail", "apiBase"])
        ),
        "comments_panel": ROOT.joinpath(
            "channel/components/widgets/CommentsPanel.brs"
        ).read_text(encoding="utf-8"),
        "comments_player": (
            seek_source + functions("channel/components/screens/PlayerScreen.brs", [
                "applyDanmakuSettings", "openComments", "closeComments",
                "layoutCommentVideo", "toggleCommentPlayback", "showHud",
            ])
            + functions("tests/ui/comments_panel.brs", [
                "fakeNode", "findFake", "createFake", "focusFake",
                "hasFakeFocus", "observeFake",
            ])
        ),
    }
    scene_doubles = functions("tests/ui/comments_panel.brs", [
        "fakeNode", "findFake", "createFake", "focusFake",
        "hasFakeFocus", "observeFake", "cjkFont",
    ])
    request_helpers = functions("channel/components/screens/PlayerScreen.brs", [
        "cancelPlayerTask", "ownsPlayerTask",
    ])
    suites["comments_player"] += request_helpers
    video_doubles = functions("tests/ui/danmaku_lifecycle.brs", [
        "testVideo", "observeVideo", "unobserveVideo", "sameVideo",
    ])
    suites["danmaku_lifecycle"] = (
        ROOT.joinpath("channel/components/widgets/DanmakuLayer.brs").read_text(encoding="utf-8")
        + scene_doubles
    )
    suites["playback_release"] = (
        ROOT.joinpath("channel/components/cast/CastPlayerAdapter.brs").read_text(encoding="utf-8")
        + seek_source
        + video_doubles
    )
    suites["remote_seek"] = (
        seek_source + scene_doubles
        + functions("channel/components/screens/PlayerScreen.brs", ["onKeyEvent"])
    )
    suites["player_requests"] = (
        scene_doubles + request_helpers + functions("channel/components/screens/PlayerScreen.brs", [
            "openVideo", "onVideoInfo", "loadRelated", "onRelatedLoaded",
            "startPart", "requestStream", "onPlay", "onState", "onQualityChoice",
            "restoreQualityChoice", "refreshInteractions", "onInteractionStatus",
            "submitInteraction", "onInteractionAction", "closePanel",
        ])
    )
    for name, source in suites.items():
        harness = ROOT.joinpath(f"tests/ui/{name}.brs").read_text(encoding="utf-8")
        target = BUILD / f"{name}.brs"
        target.write_text("\n".join([helpers, source, assertion, harness]), encoding="utf-8")
        run = subprocess.run(
            ["node", str(interpreter), str(target)],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=30,
        )
        print(run.stdout.strip())
        if run.returncode or "FAIL:" in run.stdout or f"PASS {name}" not in run.stdout:
            print(run.stderr)
            raise SystemExit(f"{name} failed")


if __name__ == "__main__":
    main()
