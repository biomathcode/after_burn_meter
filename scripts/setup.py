#!/usr/bin/env python3
"""Download the pinned official SDK into the workspace, then generate Xcode."""
import argparse
import json
import re
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
VERSION = "3.5.0"
SDK = ROOT / ".vendor/smartspectra"
parser = argparse.ArgumentParser()
parser.add_argument("--team", default="", help="Apple Development Team ID")
args = parser.parse_args()
local_config = ROOT / ".afterburn-local.json"
if not args.team:
    if local_config.exists():
        args.team = json.loads(local_config.read_text()).get("team", "")
    else:
        previous = ROOT / "build/xcode/CMakeCache.txt"
        if previous.exists():
            match = re.search(r"^AFTERBURN_DEVELOPMENT_TEAM:STRING=(.+)$", previous.read_text(), re.MULTILINE)
            if match:
                args.team = match.group(1).strip()
if args.team:
    local_config.write_text(json.dumps({"team": args.team}) + "\n")
if platform.system() != "Darwin" or platform.machine() != "arm64":
    raise SystemExit("An Apple Silicon Mac running macOS 14+ is required.")
if not shutil.which("cmake"):
    raise SystemExit("Install CMake first: brew install cmake")
if not (SDK / "lib/libsmartspectra.dylib").exists():
    url = f"https://github.com/Presage-Security/SmartSpectra/releases/download/v{VERSION}/smartspectra-sdk-{VERSION}-macos-arm64.tar.gz"
    SDK.mkdir(parents=True, exist_ok=True)
    print(f"Downloading official SmartSpectra {VERSION}…")
    with tempfile.TemporaryDirectory(prefix="afterburn-sdk-") as directory:
        archive = Path(directory) / "sdk.tar.gz"
        urllib.request.urlretrieve(url, archive)
        with tarfile.open(archive) as source:
            # Refuse paths outside the chosen vendor directory on Python 3.11+.
            for member in source.getmembers():
                resolved = (SDK / member.name).resolve()
                if not resolved.is_relative_to(SDK.resolve()):
                    raise SystemExit("Unsafe SDK archive path")
            source.extractall(SDK, filter="data")
command = ["cmake", "-S", str(ROOT), "-B", str(ROOT / "build/live"), "-G", "Xcode"]
if args.team:
    command += [f"-DAFTERBURN_DEVELOPMENT_TEAM={args.team}"]
subprocess.run(command, check=True)
link = ROOT / "Afterburn.xcodeproj"
target = "build/live/Afterburn.xcodeproj"
if link.is_symlink():
    link.unlink()
if not link.exists():
    link.symlink_to(target, target_is_directory=True)
print("Open Afterburn.xcodeproj in Xcode. Set Signing & Capabilities → Team for live measurement.")

