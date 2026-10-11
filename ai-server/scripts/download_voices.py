#!/usr/bin/env python3
"""Download open-source Piper voices for the Sprichst gateway.

    python3 scripts/download_voices.py                      # the recommended voice
    python3 scripts/download_voices.py de_DE-kerstin-low    # specific voices
    python3 scripts/download_voices.py --all                # every voice in the catalogue

Voices are saved to ~/.sprichst/voices (or $PIPER_VOICES_DIR). Each is a model
file plus its config, 20 to 120 MB depending on quality. They come from
https://huggingface.co/rhasspy/piper-voices; see each voice's MODEL_CARD for its
dataset licence. You also need the engine: pip install piper-tts
"""

from __future__ import annotations

import argparse
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.voices import DEFAULT_VOICE_ID, PIPER_VOICES, default_voices_dir  # noqa: E402


def download(url: str, target: Path) -> None:
    if target.exists():
        print(f"  already have {target.name}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(target.suffix + ".part")
    print(f"  downloading {target.name} …")
    with urllib.request.urlopen(url, timeout=60) as response, partial.open("wb") as out:
        while chunk := response.read(1 << 20):
            out.write(chunk)
    partial.rename(target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("voices", nargs="*", help="voice ids, e.g. de_DE-thorsten-medium")
    parser.add_argument("--all", action="store_true", help="download every voice")
    args = parser.parse_args()

    catalogue = {v.model: v for v in PIPER_VOICES}
    wanted = list(catalogue) if args.all else (args.voices or [DEFAULT_VOICE_ID])
    unknown = [name for name in wanted if name not in catalogue]
    if unknown:
        print("Unknown voice(s):", ", ".join(unknown))
        print("Available:", ", ".join(catalogue))
        return 2

    directory = default_voices_dir()
    for name in wanted:
        voice = catalogue[name]
        print(f"{voice.label} ({voice.license})")
        download(voice.download_url, directory / f"{name}.onnx")
        download(voice.download_url + ".json", directory / f"{name}.onnx.json")
    print(f"Done. Voices are in {directory}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
