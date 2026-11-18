#!/usr/bin/env python3
"""Embed the vendor's complete dynamic runtime; never copy development secrets."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

bundle, sdk = (Path(value).resolve() for value in sys.argv[1:3])
frameworks = bundle / "Contents/Resources/SmartSpectraRuntime"
resources = bundle / "Contents/Resources"
legacy = bundle / "Contents/Frameworks"
if legacy.exists():
    shutil.rmtree(legacy)
frameworks.mkdir(parents=True, exist_ok=True)
resources.mkdir(parents=True, exist_ok=True)
shutil.copy2(sdk / "lib/libsmartspectra.dylib", frameworks)
shutil.copytree(sdk / "lib/smartspectra", frameworks / "smartspectra", dirs_exist_ok=True)
shutil.copytree(sdk / "share/smartspectra", resources / "smartspectra", dirs_exist_ok=True)
shutil.copytree(sdk / "share/doc/smartspectra", resources / "SmartSpectra-Licences", dirs_exist_ok=True)
# SmartSpectra resolves a resource manifest beside its dylib. A relative root
# keeps the complete .app relocatable; the SDK also receives a bundle-local cwd.
(frameworks / "smartspectra_manifest.json").write_text(json.dumps({
    "resource_root_dir": "../smartspectra"
}) + "\n")
identity = os.environ.get("EXPANDED_CODE_SIGN_IDENTITY", "")
if not identity or identity == "-":
    identity = "-"
for library in sorted(frameworks.rglob("*.dylib")):
    args = ["codesign", "--force", "--sign", identity]
    if identity != "-":
        args += ["--options", "runtime"]
        args += ["--timestamp"] if os.environ.get("CONFIGURATION") == "Release" else ["--timestamp=none"]
    try:
        subprocess.run(args + [str(library)], check=True, timeout=300)
    except subprocess.TimeoutExpired:
        raise SystemExit("Signing waited five minutes for Keychain authorization. Unlock the login keychain locally, then rebuild.")
    except subprocess.CalledProcessError:
        raise SystemExit("Apple could not authorize the development signing key. Check the login Keychain password and the certificate's private-key access, then rebuild.")
print("Embedded SmartSpectra runtime and notices; no .env files included.")

