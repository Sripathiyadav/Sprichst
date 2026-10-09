#!/usr/bin/env python3
"""Lists the [[PLACEHOLDER]] fields still open in legal/.

    python3 scripts/check_legal_placeholders.py            # report, exit 0
    python3 scripts/check_legal_placeholders.py --strict   # exit 1 while any remain (release pipeline)
"""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATTERN = re.compile(r"\[\[([A-Z0-9_]+)(?:,[^\]]*)?\]\]")


def main() -> int:
    found: dict[str, set[str]] = defaultdict(set)
    for path in sorted((ROOT / "legal").rglob("*.md")):
        for name in PATTERN.findall(path.read_text()):
            found[name].add(str(path.relative_to(ROOT)))
    if not found:
        print("No placeholders left in legal/.")
        return 0
    print(f"{len(found)} placeholder(s) still to fill in:\n")
    for name in sorted(found):
        print(f"  [[{name}]]")
        for file in sorted(found[name]):
            print(f"      {file}")
    return 1 if "--strict" in sys.argv else 0


if __name__ == "__main__":
    sys.exit(main())
