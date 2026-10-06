#!/usr/bin/env python3
"""Build portable release archives and verify every archived byte."""
from __future__ import annotations
import argparse
import hashlib
import json
import plistlib
import stat
import struct
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ASSETS = ROOT / "macOS-source/ShimejiNook/Assets"

def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def files_under(root):
    return {p.relative_to(root).as_posix(): p for p in root.rglob("*")
            if p.is_file() and p.name != ".DS_Store"}

def validate_assets(root):
    source = files_under(SOURCE_ASSETS)
    actual = files_under(root)
    missing = set(source) - set(actual)
    if missing:
        raise ValueError(f"Missing assets: {sorted(missing)[:5]}")
    for name, original in source.items():
        if sha256(original) != sha256(actual[name]):
            raise ValueError(f"Asset differs from source: {name}")
    for manifest in [SOURCE_ASSETS / "manifest.json",
                     *SOURCE_ASSETS.glob("Models/*/Assets/manifest.json")]:
        data = json.loads(manifest.read_text(encoding="utf-8-sig"))
        for name, animation in data["animations"].items():
            frames = sorted((manifest.parent / name).glob("frame_*.png"))
            if len(frames) != animation["frames"] or not frames:
                raise ValueError(f"Invalid frame count: {name}")
            if animation["fps"] <= 0:
                raise ValueError(f"Invalid fps: {name}")
            if any(i < 0 or i >= len(frames) for i in animation.get("playbackOrder", [])):
                raise ValueError(f"Invalid playback order: {name}")
    return len(source)

def universal_architectures(binary):
    with binary.open("rb") as stream:
        header = stream.read(8)
        if len(header) != 8:
            raise ValueError("Truncated Mach-O executable")
        magic, count = struct.unpack(">II", header)
        if magic != 0xCAFEBABE or count > 16:
            raise ValueError("Expected a universal FAT Mach-O executable")
        architectures = []
        for _ in range(count):
            record = stream.read(20)
            if len(record) != 20:
                raise ValueError("Truncated Mach-O architecture table")
            cpu, subtype, offset, size, alignment = struct.unpack(">IIIII", record)
            if offset + size > binary.stat().st_size:
                raise ValueError("Mach-O slice extends beyond executable")
            architectures.append({0x01000007: "x86_64", 0x0100000C: "arm64"}.get(cpu, hex(cpu)))
        if not {"arm64", "x86_64"} <= set(architectures):
            raise ValueError(f"Missing universal architecture: {architectures}")
        return architectures

def write_archive(output, entries, readme):
    expected = {}
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, path, executable in entries:
            info = zipfile.ZipInfo(name)
            info.create_system = 3
            mode = stat.S_IFREG | (0o755 if executable else 0o644)
            info.external_attr = mode << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            if path.is_symlink():
                info.external_attr = (stat.S_IFLNK | 0o777) << 16
                data = str(path.readlink()).encode("utf-8")
                archive.writestr(info, data)
                expected[name] = hashlib.sha256(data).hexdigest()
            else:
                with path.open("rb") as source, archive.open(info, "w", force_zip64=True) as dest:
                    digest = hashlib.sha256()
                    while chunk := source.read(1024 * 1024):
                        digest.update(chunk)
                        dest.write(chunk)
                expected[name] = digest.hexdigest()
        readme_name, readme_text = readme
        archive.writestr(readme_name, readme_text.encode("utf-8"))
        expected[readme_name] = hashlib.sha256(readme_text.encode("utf-8")).hexdigest()
    with zipfile.ZipFile(output) as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError(f"ZIP CRC failure: {bad}")
        if set(archive.namelist()) != set(expected):
            raise ValueError("ZIP entries differ from expected files")
        for name, digest in expected.items():
            with archive.open(name) as stream:
                if hashlib.file_digest(stream, "sha256").hexdigest() != digest:
                    raise ValueError(f"ZIP content mismatch: {name}")
        for name, path, executable in entries:
            if executable and not (archive.getinfo(name).external_attr >> 16) & 0o111:
                raise ValueError(f"Executable permission missing: {name}")
    return {"file": output.name, "bytes": output.stat().st_size,
            "sha256": sha256(output), "verified_entries": len(expected)}

def package_windows(app_dir, out_dir):
    exe_platform = True
    exe = app_dir / "ShimejiNook.exe"
    with exe.open("rb") as stream:
        if stream.read(2) != b"MZ":
            raise ValueError("Invalid Windows PE executable")
        stream.seek(60)
        pe_offset = struct.unpack("<I", stream.read(4))[0]
        stream.seek(pe_offset)
        if stream.read(4) != b"PE\x00\x00":
            raise ValueError("Invalid Windows PE signature")
        machine = struct.unpack("<H", stream.read(2))[0]
        architecture = {0x8664: "x64", 0xAA64: "arm64"}.get(machine)
        if not architecture:
            raise ValueError(f"Unsupported Windows architecture: {machine:#x}")
    asset_count = validate_assets(app_dir / "Assets")
    version = ET.parse(ROOT / "Windows-source/ShimejiNook.Windows.csproj").findtext(".//Version")
    if not version:
        raise ValueError("Windows version missing")
    prefix = f"Shimeji-Nook-Windows-{architecture}"
    entries = [(f"{prefix}/{name}", path, False)
               for name, path in sorted(files_under(app_dir).items())
               if path.suffix.lower() != ".pdb" and path.name not in {"runtime.log", "settings.json"}]
    entries.append((f"{prefix}/LICENSE", ROOT / "LICENSE", False))
    if exe_platform:
        entries.extend((f"{prefix}/licenses/{p.name}", p, False) for p in sorted((ROOT / "licenses").glob("*.txt")))
    result = write_archive(out_dir / f"{prefix}-v{version}.zip", entries,
        (f"{prefix}/README_TH.txt",
         f"Shimeji Nook — Windows {architecture}\nแตก ZIP ทั้งชุดก่อนเปิด ShimejiNook.exe\n"
         "เก็บ Assets ไว้ข้าง executable ไม่ต้องติดตั้ง .NET\n"
         "คลิกขวาที่ตัวละครเพื่อเปิดเมนู เลือกโมเดล Say, Emotes, Move หรือ Quit\n"
         "การเลือกโมเดลและ runtime.log อยู่ใน %LOCALAPPDATA%\\ShimejiNook\n"))
    result.update(platform=f"windows-{architecture}", version=version, asset_files=asset_count)
    return result

def package_macos(app, out_dir):
    exe_platform = False
    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    binary = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = universal_architectures(binary)
    asset_count = validate_assets(app / "Contents/Resources/Assets")
    version = info["CFBundleShortVersionString"]
    prefix = "Shimeji-Nook-macOS-universal"
    entries = [(f"{prefix}/{app.name}/{name}", path,
                name.startswith("Contents/MacOS/"))
               for name, path in sorted(files_under(app).items())]
    entries.append((f"{prefix}/LICENSE", ROOT / "LICENSE", False))
    if exe_platform:
        entries.extend((f"{prefix}/licenses/{p.name}", p, False) for p in sorted((ROOT / "licenses").glob("*.txt")))
    result = write_archive(out_dir / f"{prefix}-v{version}.zip", entries,
        (f"{prefix}/README_TH.txt",
         f"Shimeji Nook — macOS {version}\nรองรับ macOS 13+ Intel และ Apple Silicon\n"
         "แตก ZIP แล้วลาก Shimeji Nook.app ไปไว้ใน Applications\n"
         "คลิกขวาที่ตัวละครเพื่อเปิดเมนู\n"
         "อนุญาต Accessibility ให้ ShimejiNook หากต้องการเกาะหน้าต่าง\n"
         "แพ็กนี้เป็น ad-hoc signed ไม่มี Developer ID/notarization\n"))
    result.update(platform="macos-universal", version=version,
                  architectures=architectures, asset_files=asset_count,
                  executable_sha256=sha256(binary))
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=["windows", "macos", "all"], required=True)
    parser.add_argument("--windows-app", type=Path, default=ROOT / "Windows-app")
    parser.add_argument("--mac-app", type=Path, default=ROOT / "Mac-app/Shimeji Nook.app")
    parser.add_argument("--out-dir", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    results = []
    if args.platform in {"windows", "all"}:
        results.append(package_windows(args.windows_app, args.out_dir))
    if args.platform in {"macos", "all"}:
        results.append(package_macos(args.mac_app, args.out_dir))
    for result in results:
        (args.out_dir / (result["file"] + ".json")).write_text(
            json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    sums = [f"{sha256(path)}  {path.name}" for path in sorted(args.out_dir.glob("*.zip"))]
    (args.out_dir / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    print(json.dumps(results, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
