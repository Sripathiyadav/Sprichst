"""Tests for the voice catalogue and the speech endpoints.

Run with:  python -m pytest ai-server/tests   (needs fastapi, httpx, pytest)
Synthesis itself is faked, so no voice models or macOS are required.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import main  # noqa: E402
from app.voices import (  # noqa: E402
    DEFAULT_VOICE_ID,
    PIPER_VOICES,
    VoiceCatalogue,
    length_scale,
    parse_say_voices,
    system_say_command,
    system_voice_id,
)


def catalogue(tmp_path, *, installed=(), say=("Anna",), piper=True) -> VoiceCatalogue:
    for model in installed:
        (tmp_path / f"{model}.onnx").write_bytes(b"x")
    return VoiceCatalogue(
        voices_dir=tmp_path,
        say_voices=lambda: list(say),
        piper_available=lambda: piper,
    )


def test_catalogue_has_unique_ids_and_no_noncommercial_voices():
    ids = [v.id for v in PIPER_VOICES]
    assert len(ids) == len(set(ids))
    assert DEFAULT_VOICE_ID in ids
    assert all("NC" not in v.license for v in PIPER_VOICES)
    assert not any("pavoque" in v.id for v in PIPER_VOICES)


def test_download_urls_follow_the_piper_layout():
    thorsten = next(v for v in PIPER_VOICES if v.id == "de_DE-thorsten-medium")
    assert thorsten.download_url.endswith(
        "/de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx"
    )
    eva = next(v for v in PIPER_VOICES if v.id == "de_DE-eva_k-x_low")
    assert eva.download_url.endswith("/de/de_DE/eva_k/x_low/de_DE-eva_k-x_low.onnx")


def test_parses_german_system_voices_only():
    listing = (
        "Alex                en_US    # Most people recognize me\n"
        "Anna                de_DE    # Hallo! Mein Name ist Anna.\n"
        "Yannick             de_DE    # Hallo!\n"
    )
    assert parse_say_voices(listing) == ["Anna", "Yannick"]


def test_parses_the_newer_macos_voice_listing():
    listing = (
        "Albert              en_US    # Hello! My name is Albert.\n"
        "Anna (German (Germany)) de_DE    # Hallo! Ich heiße Anna.\n"
        "Anna (German (Germany)) de_DE    # Hallo! Ich heiße Anna.\n"
        "Eddy (German (Germany)) de_DE    # Hallo! Ich heiße Eddy.\n"
    )
    assert parse_say_voices(listing) == ["Anna", "Eddy"]


def test_say_text_can_never_be_read_as_an_option():
    command = system_say_command("Anna", 180, Path("/tmp/out.aiff"), "-f/etc/passwd")
    assert command[-2:] == ["--", "-f/etc/passwd"]


def test_speed_maps_to_piper_length_scale():
    assert length_scale(None) == 1.0
    assert length_scale(180) == 1.0
    assert length_scale(100) == length_scale(120)  # clamped
    assert length_scale(260) < 1.0 < length_scale(140)


def test_installed_voice_is_used_as_asked(tmp_path):
    cat = catalogue(tmp_path, installed=["de_DE-kerstin-low"])
    voice, fallback = cat.resolve("de_DE-kerstin-low")
    assert voice.id == "de_DE-kerstin-low" and not fallback


def test_missing_voice_falls_back_to_an_installed_piper_voice(tmp_path):
    cat = catalogue(tmp_path, installed=["de_DE-ramona-low"])
    voice, fallback = cat.resolve("de_DE-thorsten-medium")
    assert voice.id == "de_DE-ramona-low" and fallback


def test_with_no_piper_the_system_voice_is_the_fallback(tmp_path):
    cat = catalogue(tmp_path, installed=["de_DE-thorsten-medium"], piper=False)
    voice, fallback = cat.resolve("de_DE-thorsten-medium")
    assert voice.engine == "system" and fallback


def test_legacy_voice_names_still_resolve(tmp_path):
    cat = catalogue(tmp_path)
    voice, fallback = cat.resolve("Anna")
    assert voice.id == system_voice_id("Anna") and not fallback


def test_no_voice_requested_is_not_a_fallback(tmp_path):
    cat = catalogue(tmp_path, installed=["de_DE-thorsten-medium"])
    voice, fallback = cat.resolve(None)
    assert voice.id == "de_DE-thorsten-medium" and not fallback


def test_listing_reports_availability_and_install_hint(tmp_path):
    cat = catalogue(tmp_path, installed=["de_DE-thorsten-medium"])
    listing = cat.listing()
    by_id = {v["id"]: v for v in listing["voices"]}
    assert listing["default"] == "de_DE-thorsten-medium"
    assert by_id["de_DE-thorsten-medium"]["available"] is True
    assert by_id["de_DE-thorsten-medium"]["installHint"] is None
    assert by_id["de_DE-kerstin-low"]["available"] is False
    assert "download_voices.py" in by_id["de_DE-kerstin-low"]["installHint"]
    assert by_id[system_voice_id("Anna")]["available"] is True


# --------------------------------------------------------------------- endpoints

@pytest.fixture
def client(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient

    cat = catalogue(tmp_path, installed=["de_DE-thorsten-medium", "de_DE-kerstin-low"])
    calls = []

    class FakeEngine:
        def synthesize(self, text, voice, wpm):
            calls.append((text, voice.id, wpm))
            return b"RIFFfakewav"

    monkeypatch.setattr(main, "voice_catalogue", cat)
    monkeypatch.setattr(main, "piper_engine", FakeEngine())
    test_client = TestClient(main.app)
    test_client.calls = calls
    return test_client


def test_voices_endpoint(client):
    body = client.get("/v1/voices").json()
    assert body["default"] == "de_DE-thorsten-medium"
    assert any(v["id"] == "de_DE-kerstin-low" and v["available"] for v in body["voices"])


def test_speak_uses_the_chosen_voice_and_speed(client):
    response = client.post(
        "/v1/speak",
        json={"message": "Hallo!", "voice": "de_DE-kerstin-low", "rate": 240},
    )
    assert response.status_code == 200
    assert response.headers["x-voice-used"] == "de_DE-kerstin-low"
    assert response.headers["x-voice-fallback"] == "false"
    assert client.calls == [("Hallo!", "de_DE-kerstin-low", 240)]


def test_speak_falls_back_and_says_so(client):
    response = client.post(
        "/v1/speak", json={"message": "Hallo!", "voice": "de_DE-ramona-low"}
    )
    assert response.status_code == 200
    assert response.headers["x-voice-fallback"] == "true"
    assert response.headers["x-voice-used"] == "de_DE-thorsten-medium"


def test_speak_rejects_empty_text_and_silly_rates(client):
    assert client.post("/v1/speak", json={"message": "   "}).status_code == 400
    assert client.post("/v1/speak", json={"message": "Hi", "rate": 5}).status_code == 422


def test_speak_still_accepts_the_old_request_shape(client):
    response = client.post(
        "/v1/speak",
        json={"message": "Hallo", "context": {"level": "A1"}},
    )
    assert response.status_code == 200
