#!/usr/bin/env python3
"""Load .env without shell evaluation, logging credentials or bundling the file."""
import argparse
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
args = parser.parse_args()
app = root / "build/live/Debug/Afterburn.app"
binary = app / "Contents/MacOS/Afterburn"
if not binary.exists():
    raise SystemExit("Build first with: python3 scripts/build.py")
environment = os.environ.copy()
env_file = root / ".env"
if env_file.exists():
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:].lstrip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        if name.strip() == "SMARTSPECTRA_API_KEY":
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            environment["SMARTSPECTRA_API_KEY"] = value
command = [str(binary)]
# No credential is placed in an argument or printed to the terminal.
raise SystemExit(subprocess.call(command, env=environment, cwd=root))

