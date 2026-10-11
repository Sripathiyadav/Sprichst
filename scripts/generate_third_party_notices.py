#!/usr/bin/env python3
"""Writes legal/third-party-notices.md from pubspec.lock and ai-server/requirements.txt.

    python3 scripts/generate_third_party_notices.py          # regenerate
    python3 scripts/generate_third_party_notices.py --check  # fail if stale or a licence is unknown

Licences are detected from each package's LICENSE file in the pub cache
(run `flutter pub get` first). A package whose licence cannot be recognised is
listed as UNKNOWN and makes --check fail, so a new dependency is never shipped
without somebody reading its licence.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "legal" / "third-party-notices.md"
PUB_CACHE = Path(os.environ.get("PUB_CACHE", Path.home() / ".pub-cache")) / "hosted" / "pub.dev"

# Order matters: the first match wins.
LICENCES = [
    ("Apache-2.0", r"apache license[\s,]+version 2\.0"),
    ("MPL-2.0", r"mozilla public license[\s,]+(version |v\.? ?)?2\.0"),
    ("BSD-3-Clause", r"redistribution and use in source and binary forms[\s\S]*neither the name"),
    ("BSD-2-Clause", r"redistribution and use in source and binary forms"),
    ("MIT", r"permission is hereby granted, free of charge"),
    ("ISC", r"permission to use, copy, modify, and/or distribute this software"),
    ("Zlib", r"this software is provided 'as-is'"),
    ("Unlicense", r"this is free and unencumbered software"),
]

# Packages that ship from the Flutter SDK rather than the pub cache.
SDK_PACKAGES = {"flutter", "flutter_test", "flutter_web_plugins", "sky_engine", "flutter_localizations"}


def parse_lock() -> list[tuple[str, str, str, str]]:
    packages, name, kind, version, source = [], None, "", "", ""
    for line in (ROOT / "pubspec.lock").read_text().splitlines():
        m = re.match(r"^  (\S+):$", line)
        if m:
            if name:
                packages.append((name, version, kind, source))
            name, kind, version, source = m.group(1), "", "", ""
        elif line.startswith("    dependency:"):
            kind = line.split(":", 1)[1].strip().strip('"')
        elif line.startswith("    version:"):
            version = line.split(":", 1)[1].strip().strip('"')
        elif line.startswith("    source:"):
            source = line.split(":", 1)[1].strip()
    if name:
        packages.append((name, version, kind, source))
    return sorted(packages)


def detect(name: str, version: str, source: str) -> str:
    if name in SDK_PACKAGES or source == "sdk":
        return "BSD-3-Clause (Flutter SDK)"
    if source == "path":
        return "Project-owned stub"
    folder = PUB_CACHE / f"{name}-{version}"
    files = [p for p in (folder.glob("LICENSE*") if folder.is_dir() else [])]
    files += [p for p in (folder.glob("COPYING*") if folder.is_dir() else [])]
    if not files:
        return "UNKNOWN (package not in pub cache)"
    text = " ".join(f.read_text(errors="ignore") for f in files).lower()
    found = [spdx for spdx, pattern in LICENCES if re.search(pattern, text)]
    if not found:
        return "UNKNOWN (unrecognised licence text)"
    if "Apache-2.0" in found and len(found) > 1:
        return "Apache-2.0 (and " + ", ".join(f for f in found if f != "Apache-2.0") + ")"
    return found[0]


def python_requirements() -> list[str]:
    path = ROOT / "ai-server" / "requirements.txt"
    return [l.strip() for l in path.read_text().splitlines() if l.strip() and not l.startswith("#")]


STATIC = """\
## Bundled with the app

| Component | Licence | Notes |
|---|---|---|
| Figtree font (assets/fonts/figtree) | SIL OFL 1.1 | The design system's family, bundled so no font is fetched from a CDN. Licence text: assets/fonts/figtree/OFL.txt |
| Roboto font (assets/fonts/roboto) | Apache-2.0 | Fallback; bundled so no font is fetched from Google. Licence text: assets/fonts/roboto/LICENSE.txt |
| Firebase JS SDK (web/vendor/firebasejs) | Apache-2.0 | Vendored so the web app loads no code from gstatic.com. See web/vendor/firebasejs/NOTICE |
| Flutter engine and CanvasKit (web build) | BSD-3-Clause | Served from our own origin |
| Material Icons (Flutter SDK) | Apache-2.0 | |
| App icon, orbit mark and artwork | Project-owned | assets/brand/, written to every platform by scripts/make_app_icons.py |

## AI models and voices (downloaded on request, not bundled)

| Model | Licence | Source |
|---|---|---|
| Qwen2.5 0.5B and 1.5B Instruct | Apache-2.0 | huggingface.co/Qwen |
| Gemma 3 1B and 4B (unsloth GGUF builds) | Gemma Terms of Use and Prohibited Use Policy | huggingface.co/unsloth |
| Whisper tiny and base (sherpa-onnx builds) | MIT | huggingface.co/csukuangfj |
| Piper German voices Thorsten, Kerstin | CC0 1.0 | huggingface.co/rhasspy/piper-voices |
| Piper German voices Ramona, Karlsson, Eva | M-AILABS open data | huggingface.co/rhasspy/piper-voices |
| Piper (engine) and sherpa-onnx | MIT / Apache-2.0 | github.com/rhasspy/piper, github.com/k2-fsa/sherpa-onnx |

Qwen2.5 3B is deliberately excluded because its licence restricts commercial use. The Pavoque voice is excluded because its training data is CC BY-NC-SA.

Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms.
"""


def render() -> tuple[str, int]:
    lines = [
        "# Third-Party Notices",
        "",
        "Sprichst includes open-source software and data. This file is generated by "
        "`python3 scripts/generate_third_party_notices.py`; do not edit it by hand. "
        "Full licence texts are shown in the app under Account → About Sprichst → View licenses.",
        "",
        STATIC,
        "## Dart and Flutter packages",
        "",
        "| Package | Version | Licence | Used for |",
        "|---|---|---|---|",
    ]
    unknown = 0
    kinds = {"direct main": "app", "direct dev": "tests and tools", "direct overridden": "app", "transitive": "dependency"}
    for name, version, kind, source in parse_lock():
        licence = detect(name, version, source)
        unknown += licence.startswith("UNKNOWN")
        lines.append(f"| {name} | {version} | {licence} | {kinds.get(kind, kind)} |")
    lines += ["", "## Developer AI gateway (Python, not part of the released app)", "", "| Requirement |", "|---|"]
    lines += [f"| {r} |" for r in python_requirements()]
    lines += ["", "Python packages are installed by the server operator from PyPI under their own licences "
              "(FastAPI MIT, Uvicorn BSD-3-Clause, python-dotenv BSD-3-Clause, python-multipart Apache-2.0, "
              "PyJWT MIT, cryptography Apache-2.0 or BSD-3-Clause, plus their own dependencies).", ""]
    return "\n".join(lines), unknown


def main() -> int:
    text, unknown = render()
    if "--check" in sys.argv:
        stale = not OUT.exists() or OUT.read_text() != text
        if stale:
            print("legal/third-party-notices.md is out of date; run scripts/generate_third_party_notices.py")
        if unknown:
            print(f"{unknown} package(s) with an unrecognised licence; read them and extend LICENCES")
        return 1 if stale or unknown else 0
    OUT.write_text(text)
    print(f"wrote {OUT.relative_to(ROOT)} ({unknown} unknown licences)")
    return 1 if unknown else 0


if __name__ == "__main__":
    sys.exit(main())
