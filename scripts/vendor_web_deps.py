#!/usr/bin/env python3
"""Self-host the Firebase JS SDK that FlutterFire would otherwise load from Google.

FlutterFire for web injects <script> tags for https://www.gstatic.com/firebasejs/
on every start-up, so Google receives the IP address of everyone who opens the
app, before they have done anything. If `window.firebase_core` already exists it
skips that, so web/flutter_bootstrap.js imports the copies this script saves.

    python3 scripts/vendor_web_deps.py          # (re)download the files
    python3 scripts/vendor_web_deps.py --check  # fail if they are missing or stale

The version comes from the firebase_core_web package that pubspec.lock resolves,
because FlutterFire is only tested against that exact SDK version. Run this
after upgrading Firebase packages (the privacy tests fail until you do).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "web" / "vendor" / "firebasejs"

# FlutterFire's window variable -> the bundle it loads.
BUNDLES = {
    "firebase-app.js": "firebase-app.js",
    "firebase-auth.js": "firebase-auth.js",
    # FlutterFire loads this bundle for Firestore (it also covers normal queries).
    "firebase-firestore-pipelines.js": "firebase-firestore-pipelines.js",
}
CDN = "https://www.gstatic.com/firebasejs/{version}/{name}"


def package_dir(name: str) -> Path:
    config = json.loads((ROOT / ".dart_tool" / "package_config.json").read_text())
    for package in config["packages"]:
        if package["name"] == name:
            root = package["rootUri"]
            return Path(root[len("file://"):]) if root.startswith("file://") else (
                ROOT / ".dart_tool" / root).resolve()
    raise SystemExit(f"{name} is not a dependency (run `flutter pub get`).")


def supported_version() -> str:
    source = (package_dir("firebase_core_web") / "lib" / "src" / "firebase_sdk_version.dart").read_text()
    match = re.search(r"supportedFirebaseJsSdkVersion\s*=\s*'([^']+)'", source)
    if not match:
        raise SystemExit("Could not read the Firebase JS SDK version.")
    return match.group(1)


def vendored_version() -> str | None:
    marker = TARGET / "VERSION"
    return marker.read_text().strip() if marker.exists() else None


def download(version: str) -> None:
    TARGET.mkdir(parents=True, exist_ok=True)
    for name in BUNDLES:
        url = CDN.format(version=version, name=name)
        print(f"  {url}")
        with urllib.request.urlopen(url, timeout=60) as response:
            code = response.read().decode("utf-8")
        # The bundles import firebase-app.js by absolute CDN URL; make it relative
        # so nothing is requested from Google.
        code = code.replace(CDN.format(version=version, name="firebase-app.js"), "./firebase-app.js")
        if "gstatic.com/firebasejs" in code:
            raise SystemExit(f"{name} still points at the Firebase CDN; update this script.")
        (TARGET / name).write_text(code, encoding="utf-8")
    (TARGET / "VERSION").write_text(version + "\n")
    (TARGET / "NOTICE").write_text(
        "Firebase JavaScript SDK " + version + "\n"
        "Copyright Google LLC. Licensed under the Apache License, Version 2.0\n"
        "(see assets/fonts/roboto/LICENSE.txt for the licence text, or\n"
        "https://www.apache.org/licenses/LICENSE-2.0).\n"
        "Source: https://github.com/firebase/firebase-js-sdk\n"
        "Self-hosted so visitors' IP addresses are not sent to www.gstatic.com.\n"
        "Regenerate with: python3 scripts/vendor_web_deps.py\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    wanted = supported_version()
    have = vendored_version()
    missing = [n for n in BUNDLES if not (TARGET / n).exists()]
    if args.check:
        if have != wanted or missing:
            print(f"Vendored Firebase JS SDK is {have or 'missing'}, packages need {wanted}"
                  f"{'; missing ' + ', '.join(missing) if missing else ''}.")
            print("Run: python3 scripts/vendor_web_deps.py")
            return 1
        print(f"Firebase JS SDK {wanted} is vendored.")
        return 0
    print(f"Saving Firebase JS SDK {wanted} to {TARGET.relative_to(ROOT)}")
    download(wanted)
    return 0


if __name__ == "__main__":
    sys.exit(main())
