"""Assemble a local Windows release from verified official runtime archives.

No network access, installation, MATLAB execution, or original-project writes.
Run with a normal Python 3.12+ interpreter, not the isolated bundled interpreter.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import zipfile

from bundle_workspace import build_workspace, digest


def unpack(archive: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    root = destination.resolve()
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            relative = PurePosixPath(entry.filename)
            if (relative.is_absolute() or ".." in relative.parts or
                    "\\" in entry.filename or ":" in entry.filename or
                    stat.S_ISLNK(entry.external_attr >> 16)):
                raise ValueError(f"Unsafe archive entry: {entry.filename}")
            target = root.joinpath(*relative.parts)
            if not target.resolve().is_relative_to(root):
                raise ValueError(f"Archive entry leaves output: {entry.filename}")
        package.extractall(root)


def build(source: Path, cache: Path, destination: Path) -> dict:
    source, cache, destination = source.resolve(), cache.resolve(), destination.resolve()
    if destination == source or destination.is_relative_to(source) or source.is_relative_to(destination):
        raise ValueError("Build into a separate release folder outside the source project.")
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise ValueError("The release folder must be new or empty.")
    desktop = source / "12_Workbench/desktop"
    lock = json.loads((desktop / "runtime-lock.json").read_text(encoding="utf-8"))
    for runtime in lock.values():
        archive = cache / runtime["archive"]
        if digest(archive) != runtime["sha256"]:
            raise ValueError(f"Runtime hash mismatch: {archive.name}")
    # Check app inputs before creating a partial release.
    for relative in ("main.js", "package.json", "icon.ico", "README.md", "Launch-Desktop.cmd"):
        if not (desktop / relative).is_file():
            raise FileNotFoundError(desktop / relative)
    shortcut = source / "Open EMI Workbench.lnk"
    if not shortcut.is_file():
        raise FileNotFoundError(shortcut)
    destination.mkdir(parents=True, exist_ok=True)
    unpack(cache / lock["electron"]["archive"], destination)
    (destination / "electron.exe").rename(destination / "EMI Robotics.exe")
    shutil.copy2(shortcut, destination / shortcut.name)
    shutil.copy2(desktop / "Launch-Desktop.cmd", destination / "Start EMI Workbench.cmd")
    resources = destination / "resources"
    unpack(cache / lock["python"]["archive"], resources / "python")
    # Remove only Electron's generated default demo from this fresh release.
    demo = resources / "default_app.asar"
    if demo.is_file():
        demo.unlink()
    app = resources / "app"
    app.mkdir()
    for name in ("main.js", "package.json", "icon.ico"):
        shutil.copy2(desktop / name, app / name)
    shutil.copy2(desktop / "README.md", destination / "START HERE.md")
    shutil.copy2(desktop / "runtime-lock.json", destination / "runtime-lock.json")
    workspace = destination / "workspace"
    build_workspace(source, workspace)
    workbench = workspace / "12_Workbench"
    for name in ("server.py", "acceptance.py", "README.md"):
        shutil.copy2(source / "12_Workbench" / name, workbench / name)
    for folder in ("web", "tests", "desktop"):
        shutil.copytree(source / "12_Workbench" / folder, workbench / folder,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "node_modules"))
    # The scientific bundle manifest preserves source identity; this manifest
    # additionally covers application code, runtimes, and third-party notices.
    files = []
    for file in sorted(destination.rglob("*")):
        if file.is_file():
            files.append({"path": file.relative_to(destination).as_posix(),
                          "bytes": file.stat().st_size, "sha256": digest(file)})
    version = json.loads((desktop / "package.json").read_text(encoding="utf-8"))["version"]
    manifest = {"product": "EMI Robotics Signal Lab", "version": version,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "platform": "Windows x64", "runtimes": lock,
                "matlab_included": False, "files": files}
    (destination / "release_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return {"destination": str(destination), "files": len(files),
            "bytes": sum(file["bytes"] for file in files), "runtime_hashes_verified": True}


def create_archive(release: Path, archive: Path) -> dict:
    """Zip only verified release files; omit active locks and machine caches."""
    release, archive = release.resolve(), archive.resolve()
    if archive.exists() or archive.is_relative_to(release):
        raise ValueError("Archive must be new and outside the release folder.")
    manifest = json.loads((release / "release_manifest.json").read_text(encoding="utf-8"))
    selected = []
    for record in manifest["files"]:
        name = record["path"]
        relative = PurePosixPath(name)
        if relative.is_absolute() or ".." in relative.parts or "\\" in name or ":" in name:
            raise ValueError("Invalid release path: " + name)
        file = release.joinpath(*relative.parts)
        if not file.resolve().is_relative_to(release) or digest(file) != record["sha256"]:
            raise ValueError("Release file changed: " + name)
        selected.append(file)
    selected.append(release / "release_manifest.json")
    with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as package:
        for file in selected:
            package.write(file, (Path(release.name) / file.relative_to(release)).as_posix())
    return {"archive": str(archive), "bytes": archive.stat().st_size,
            "sha256": digest(archive), "files": len(selected)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--runtime-cache", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--archive", type=Path, help="Optional new portable ZIP outside the release folder")
    args = parser.parse_args()
    print(json.dumps(build(args.source, args.runtime_cache, args.destination), indent=2))
    if args.archive:
        print(json.dumps(create_archive(args.destination, args.archive), indent=2))
