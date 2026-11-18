#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--team", default="")
parser.add_argument("--release", action="store_true")
parser.add_argument("--development", action="store_true", help="Build locally with ad-hoc signing for interface testing")
args = parser.parse_args()
local = root / ".afterburn-local.json"
if not args.team and local.exists():
    args.team = json.loads(local.read_text()).get("team", "")
setup = [sys.executable, str(root / "scripts/setup.py")]
if args.team:
    setup += ["--team", args.team]
subprocess.run(setup, check=True)
if not args.team and local.exists():
    args.team = json.loads(local.read_text()).get("team", "")
if not args.team:
    raise SystemExit("Live measurement requires a development team. Run with --team YOUR_TEAM_ID.")
command = ["xcodebuild", "-project", str(root / "build/live/Afterburn.xcodeproj"),
           "-scheme", "Afterburn", "-configuration", "Release" if args.release else "Debug",
           "-derivedDataPath", str(root / "build/LiveDerivedData"), "build"]
if args.development:
    command += ["CODE_SIGNING_ALLOWED=NO"]
subprocess.run(command, check=True)
app = root / "build/live" / ("Release" if args.release else "Debug") / "Afterburn.app"
if args.development:
    subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
    print("Local development build. Live SDK measurement requires Apple Development signing.")
print(f"App: {app}")

