"""Build a temporary TV-only screensaver entry-point experiment.

Reuses the network lifecycle probe; never modifies channel/ or its package.
Hybrid mode tests side-loading behavior, not eligibility for Roku publication.
"""

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "experiments/lifecycle-probe"
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("hybrid", "screensaver"), default="hybrid")
    parser.add_argument(
        "--legacy-public-flag", action="store_true",
        help="Probe the legacy screensaver_private=0 flag; no support assumed.",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest = (BASE / "manifest").read_text(encoding="utf-8")
    manifest = manifest.replace("Roku network lifecycle probe", "Roku startup experiment")
    manifest = manifest.replace("RokuLifecycleProbe", "RokuStartupProbe")
    manifest += "screensaver_title=Roku startup experiment\n"
    if args.legacy_public_flag:
        manifest += "screensaver_private=0\n"
    main_source = (HERE / "entry.brs").read_text(encoding="utf-8")
    if args.mode == "hybrid":
        main_source = (
            'sub Main(args as Dynamic)\n'
            '    startProbe("main")\n'
            'end sub\n\n' + main_source
        )
    files = {"manifest": manifest, "source/main.brs": main_source}
    for path in (BASE / "components").glob("*"):
        text = path.read_text(encoding="utf-8")
        if path.name == "ProbeTask.brs":
            assert text.count('info = CreateObject("roDeviceInfo")') == 1
            text = text.replace(
                'info = CreateObject("roDeviceInfo")',
                'info = CreateObject("roDeviceInfo")\n    entryRole = m.global.entryRole',
            )
            text = text.replace("instance: instance", "instance: instance, entry: entryRole")
            text = text.replace("RokuLifecycleProbe", "RokuStartupProbe")
        elif path.name == "ProbeScene.xml":
            text = text.replace(
                "Roku network lifecycle experiment", "Roku startup experiment"
            ).replace(
                "Testing TCP and UDP after Home / standby.",
                "Temporary screensaver entry-point test.",
            )
        files[path.relative_to(BASE).as_posix()] = text
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(args.output, "w", compression=ZIP_DEFLATED) as archive:
        for name, text in files.items():
            archive.writestr(name, text.encode("utf-8"))
    print(f"{args.mode}: {args.output} ({len(files)} files)")


if __name__ == "__main__":
    main()
