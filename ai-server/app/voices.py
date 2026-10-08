"""Text-to-speech voices for the Sprichst gateway.

Voices come from two engines:

* **Piper** (open source, runs offline on the gateway). The German voices below
  are published at https://huggingface.co/rhasspy/piper-voices. Pavoque is left
  out on purpose: its training data is licensed non-commercially (CC BY-NC-SA).
* **System** voices (macOS ``say``), used as a fallback when no Piper voice is
  installed, so the app always has something to speak with.

This module has no web-framework dependency so it can be tested on its own.
"""

from __future__ import annotations

import io
import json
import os
import re
import subprocess
import sys
import wave
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional

DEFAULT_VOICE_ID = "de_DE-thorsten-medium"
LEGACY_SYSTEM_VOICE = "Anna"  # what older app versions stored as the voice name

# Words per minute the app's speed slider reports as "normal".
NORMAL_WPM = 180
MIN_WPM, MAX_WPM = 120, 320

HF_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/de/de_DE"


@dataclass(frozen=True)
class Voice:
    id: str
    label: str
    engine: str  # "piper" | "system"
    description: str
    license: str
    quality: str = ""
    # Piper only: the model's file stem, e.g. "de_DE-thorsten-medium".
    model: str = ""
    # Piper only: which speaker of a multi-speaker model to use (by name).
    speaker: Optional[str] = None

    @property
    def download_url(self) -> str:
        """Where the Piper model file lives (the config is the same + ".json")."""
        _, name, quality = self.model.split("-", 2)
        return f"{HF_BASE}/{name}/{quality}/{self.model}.onnx"


def _piper(
    model: str, label: str, description: str, license: str, quality: str,
    speaker: Optional[str] = None,
) -> Voice:
    return Voice(
        id=model, label=label, engine="piper", description=description,
        license=license, quality=quality, model=model, speaker=speaker,
    )


PIPER_VOICES: tuple[Voice, ...] = (
    _piper("de_DE-thorsten-medium", "Thorsten",
           "Clear, natural male voice. The best all-round open German voice.",
           "CC0 (public domain)", "medium"),
    _piper("de_DE-thorsten-high", "Thorsten (high quality)",
           "The same voice at higher fidelity. Larger and slower to generate.",
           "CC0 (public domain)", "high"),
    _piper("de_DE-thorsten_emotional-medium", "Thorsten (expressive)",
           "The same speaker with a livelier, more expressive delivery.",
           "CC0 (public domain)", "medium", speaker="neutral"),
    _piper("de_DE-kerstin-low", "Kerstin",
           "Light, friendly voice. Small and fast.",
           "CC0 (public domain)", "low"),
    _piper("de_DE-ramona-low", "Ramona",
           "Calm, even voice for careful listening practice. Small and fast.",
           "Open data (M-AILABS)", "low"),
    _piper("de_DE-karlsson-low", "Karlsson",
           "Steady voice with a measured pace. Small and fast.",
           "Open data (M-AILABS)", "low"),
    _piper("de_DE-eva_k-x_low", "Eva",
           "Very small model: runs anywhere, with a more synthetic sound.",
           "Open data (M-AILABS)", "x_low"),
)

_BY_ID = {v.id: v for v in PIPER_VOICES}


def system_voice_id(name: str) -> str:
    return "system-" + re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def parse_say_voices(listing: str) -> list[str]:
    """German voice names from the output of ``say -v '?'``."""
    names: list[str] = []
    for line in listing.splitlines():
        # Older macOS pads the name with spaces ("Anna      de_DE  # ...");
        # newer releases add the language ("Anna (German (Germany)) de_DE").
        match = re.match(r"^(.+?)\s+(de[_-][A-Za-z]+)\s+#", line)
        if not match:
            continue
        name = re.sub(r"\s*\(.*\)$", "", match.group(1)).strip()
        if name and name not in names:
            names.append(name)
    return names


def _list_say_voices() -> list[str]:
    if sys.platform != "darwin" or not Path("/usr/bin/say").exists():
        return []
    try:
        result = subprocess.run(
            ["/usr/bin/say", "-v", "?"], capture_output=True, text=True,
            errors="replace", timeout=10, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    return parse_say_voices(result.stdout)


@dataclass
class VoiceCatalogue:
    """The voices this gateway can offer, and which of them work right now."""

    voices_dir: Path
    say_voices: Callable[[], list[str]] = _list_say_voices
    piper_available: Callable[[], bool] = lambda: _piper_importable()
    _system: Optional[list[Voice]] = field(default=None, init=False, repr=False)

    def system_voices(self) -> list[Voice]:
        if self._system is None:
            names = self.say_voices()
            if LEGACY_SYSTEM_VOICE not in names and names:
                names = [LEGACY_SYSTEM_VOICE, *names]
            self._system = [
                Voice(
                    id=system_voice_id(name), label=f"{name} (system)",
                    engine="system",
                    description="Built-in voice of this computer. Always available.",
                    license="Operating system",
                    model=name,
                )
                for name in names
            ]
        return self._system

    def model_path(self, voice: Voice) -> Path:
        return self.voices_dir / f"{voice.model}.onnx"

    def is_installed(self, voice: Voice) -> bool:
        if voice.engine == "system":
            return True
        return self.piper_available() and self.model_path(voice).is_file()

    def all(self) -> list[Voice]:
        return [*PIPER_VOICES, *self.system_voices()]

    def listing(self) -> dict:
        return {
            "default": self.default().id,
            "voices": [
                {
                    "id": v.id,
                    "label": v.label,
                    "engine": v.engine,
                    "description": v.description,
                    "license": v.license,
                    "quality": v.quality,
                    "available": self.is_installed(v),
                    "installHint": (
                        None if self.is_installed(v)
                        else "python3 scripts/download_voices.py " + v.model
                    ),
                }
                for v in self.all()
            ],
        }

    def lookup(self, voice_id: Optional[str]) -> Optional[Voice]:
        """The voice named by [voice_id], accepting older stored names."""
        if not voice_id:
            return None
        if voice_id in _BY_ID:
            return _BY_ID[voice_id]
        for voice in self.system_voices():
            if voice.id == voice_id or voice.model.lower() == voice_id.lower():
                return voice
        return None

    def default(self) -> Voice:
        """The best voice that works: the default Piper voice, else any
        installed Piper voice, else a system voice."""
        preferred = _BY_ID[DEFAULT_VOICE_ID]
        if self.is_installed(preferred):
            return preferred
        for voice in PIPER_VOICES:
            if self.is_installed(voice):
                return voice
        system = self.system_voices()
        return system[0] if system else preferred

    def resolve(self, voice_id: Optional[str]) -> tuple[Voice, bool]:
        """The voice to use for a request, and whether it is a fallback."""
        wanted = self.lookup(voice_id)
        if wanted is not None and self.is_installed(wanted):
            return wanted, False
        return self.default(), wanted is not None or bool(voice_id)


def _piper_importable() -> bool:
    try:
        import piper  # noqa: F401
    except Exception:
        return False
    return True


def length_scale(wpm: Optional[int]) -> float:
    """Piper's ``length_scale`` for a speed in words per minute (larger = slower)."""
    clamped = max(MIN_WPM, min(MAX_WPM, wpm or NORMAL_WPM))
    return round(NORMAL_WPM / clamped, 3)


class PiperEngine:
    """Loads Piper voices on first use and keeps them in memory."""

    def __init__(self, catalogue: VoiceCatalogue) -> None:
        self._catalogue = catalogue
        self._loaded: dict[str, object] = {}

    def synthesize(self, text: str, voice: Voice, wpm: Optional[int]) -> bytes:
        from piper import PiperVoice  # imported lazily: Piper is optional
        from piper.config import SynthesisConfig  # type: ignore

        loaded = self._loaded.get(voice.model)
        if loaded is None:
            loaded = PiperVoice.load(str(self._catalogue.model_path(voice)))
            self._loaded[voice.model] = loaded

        config_kwargs: dict = {"length_scale": length_scale(wpm)}
        speaker_id = self._speaker_id(voice)
        if speaker_id is not None:
            config_kwargs["speaker_id"] = speaker_id

        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wav:
            loaded.synthesize_wav(  # type: ignore[attr-defined]
                text, wav, syn_config=SynthesisConfig(**config_kwargs)
            )
        return buffer.getvalue()

    def _speaker_id(self, voice: Voice) -> Optional[int]:
        if not voice.speaker:
            return None
        config = Path(str(self._catalogue.model_path(voice)) + ".json")
        try:
            mapping = json.loads(config.read_text()).get("speaker_id_map", {})
        except (OSError, ValueError):
            return None
        return mapping.get(voice.speaker)


def system_say_command(voice_name: str, wpm: Optional[int], output: Path, text: str) -> list[str]:
    rate = max(MIN_WPM, min(MAX_WPM, wpm or NORMAL_WPM))
    # "--" ends option parsing, so text such as "-f/path" is spoken rather
    # than read as an option (say -f would read and speak that file).
    return ["/usr/bin/say", "-v", voice_name, "-r", str(rate), "-o", str(output), "--", text]


def default_voices_dir() -> Path:
    return Path(
        os.getenv("PIPER_VOICES_DIR", str(Path.home() / ".sprichst" / "voices"))
    ).expanduser()
