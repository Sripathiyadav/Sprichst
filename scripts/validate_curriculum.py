"""Validate the minimal Sprichst curriculum contract before publishing content."""

from __future__ import annotations

import json
import sys
from pathlib import Path

REQUIRED = {"id", "level", "skill", "topic", "title", "objective", "examples"}
ROOT = Path(__file__).resolve().parents[1] / "curriculum"


def main() -> int:
    invalid = []
    seen_ids = set()
    for path in sorted(ROOT.rglob("*.json")):
        try:
            content = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            invalid.append(f"{path.relative_to(ROOT)}: invalid JSON ({error.msg})")
            continue
        missing = REQUIRED - content.keys()
        if missing:
            invalid.append(f"{path.relative_to(ROOT)}: missing {', '.join(sorted(missing))}")
        if content.get("id") in seen_ids:
            invalid.append(f"{path.relative_to(ROOT)}: duplicate id {content['id']}")
        seen_ids.add(content.get("id"))
        if not isinstance(content.get("examples"), list) or not content["examples"]:
            invalid.append(f"{path.relative_to(ROOT)}: examples must be a non-empty list")
    if invalid:
        print("Curriculum validation failed:")
        print("\n".join(f"- {message}" for message in invalid))
        return 1
    print(f"Curriculum valid: {len(seen_ids)} lesson chunks checked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
