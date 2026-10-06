#!/usr/bin/env python3
"""Archive only Git source files; never include ignored application builds."""
import argparse
import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--out-dir", type=Path, default=ROOT / "dist")
parser.add_argument("--git", default=shutil.which("git"))
args = parser.parse_args()
if not args.git:
    parser.error("Git is required")
listed = subprocess.check_output([args.git, "-C", str(ROOT), "ls-files",
    "--cached", "--others", "--exclude-standard", "-z"])
files = sorted(set(name.decode("utf-8") for name in listed.split(b"\0") if name))
if not files:
    raise ValueError("No source files. Run git init first.")
for name in files:
    path = (ROOT / name).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError(f"Source outside repository: {name}")
    if path.stat().st_size >= 100 * 1024 * 1024:
        raise ValueError(f"Source file too large for GitHub: {name}")
    if name.startswith(("Windows-app/", "Mac-app/", ".tools/", ".build/", "dist/")):
        raise ValueError(f"Build output would be archived: {name}")
args.out_dir.mkdir(parents=True, exist_ok=True)
output = args.out_dir / "Shimeji-Nook-GitHub-source.zip"
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for name in files:
        info = zipfile.ZipInfo("shimeji-nook/" + name)
        info.create_system = 3
        info.external_attr = (0o100755 if name.endswith(".command") else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, (ROOT / name).read_bytes())
with zipfile.ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise ValueError("Source ZIP CRC failure")
    for name in files:
        if hashlib.sha256(archive.read("shimeji-nook/" + name)).hexdigest() != digest(ROOT / name):
            raise ValueError(f"Source ZIP differs: {name}")
sums = [f"{digest(path)}  {path.name}" for path in sorted(args.out_dir.glob("*.zip"))]
(args.out_dir / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
report = {"file": output.name, "source_files": len(files), "bytes": output.stat().st_size,
          "sha256": digest(output), "largest_source_bytes": max((ROOT / p).stat().st_size for p in files)}
(args.out_dir / (output.name + ".json")).write_text(
    json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
