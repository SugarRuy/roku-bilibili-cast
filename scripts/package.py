"""Package channel/ as a Roku developer ZIP without local credentials or logs."""
from hashlib import sha256
from pathlib import Path
from sys import argv
from zipfile import ZIP_DEFLATED, ZipFile


def main():
    root = Path(__file__).resolve().parents[1]
    channel = root / "channel"
    destination = Path(argv[1]).resolve() if len(argv) > 1 else root / "build/channel.zip"
    files = sorted(path for path in channel.rglob("*") if path.is_file())
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            archive.write(path, path.relative_to(channel).as_posix())
    with ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert archive.read("manifest") == (channel / "manifest").read_bytes()
        assert len(archive.namelist()) == len(files)
    print(f"{destination} ({len(files)} files, sha256 {sha256(destination.read_bytes()).hexdigest()})")


if __name__ == "__main__":
    main()
