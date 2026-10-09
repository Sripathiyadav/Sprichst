"""Model-output validation, concurrency limits, provider fallback, request ids, readiness."""

from __future__ import annotations

import sys
import threading
from pathlib import Path

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import main  # noqa: E402
from app.reliability import (  # noqa: E402
    Busy,
    InferenceLimiter,
    ModelOutputError,
    parse_chat,
    parse_correction,
    request_id,
)
from app.security import RateLimiter  # noqa: E402

WAV = b"RIFF\x24\x00\x00\x00WAVEfmt " + b"\x00" * 20


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(main, "rate_limiter", RateLimiter(limit=1000))
    monkeypatch.setattr(main, "token_verifier", None)
    monkeypatch.setattr(main, "AI_PROVIDER", "ollama")
    monkeypatch.setattr(main, "AI_FALLBACK_PROVIDER", "")
    return TestClient(main.app)


def provider(monkeypatch, fn):
    monkeypatch.setattr(main, "_call_provider", fn)


def chat(client):
    return client.post("/v1/chat", json={"message": "Hallo"})


# ------------------------------------------------------- output validation

def test_a_good_chat_answer_is_cleaned():
    out = parse_chat(
        {"reply": " Hallo! ", "correction": "", "explanation": None, "followUp": "Wo wohnst du?", "extra": "x"}
    )
    assert out == {
        "reply": "Hallo!",
        "correction": None,
        "explanation": None,
        "followUp": "Wo wohnst du?",
    }


@pytest.mark.parametrize(
    "bad",
    [
        [],
        "text",
        {},
        {"reply": ["not", "text"]},
        {"reply": "ok", "correction": {"a": 1}},
        {"reply": 5},
        {"reply": "x" * 1501},
    ],
)
def test_an_unusable_chat_answer_is_refused(bad):
    with pytest.raises(ModelOutputError):
        parse_chat(bad)


def test_correction_needs_a_corrected_sentence_and_derives_the_rest():
    out = parse_correction({"corrected": "Ich gehe."}, "Ich gehe.")
    assert out["correct"] is True and out["original"] == "Ich gehe." and out["mistakes"] == []
    out = parse_correction({"corrected": "Ich gehe.", "mistakes": None}, "Ich gehen.")
    assert out["correct"] is False
    with pytest.raises(ModelOutputError):
        parse_correction({"corrected": ""}, "x")
    with pytest.raises(ModelOutputError):
        parse_correction({"corrected": "x", "mistakes": "oops"}, "x")
    with pytest.raises(ModelOutputError):
        parse_correction({"corrected": "x", "mistakes": [1, 2]}, "x")


def test_the_api_answers_502_for_garbage_and_200_for_good_output(client, monkeypatch):
    provider(monkeypatch, lambda *a: {"reply": ["bad"]})
    assert chat(client).status_code == 502
    provider(monkeypatch, lambda *a: {"reply": "Hallo!", "followUp": "Wie geht's?", "debug": "secret"})
    response = chat(client)
    assert response.status_code == 200
    assert "debug" not in response.json()
    provider(monkeypatch, lambda *a: {"corrected": "Ich gehe.", "explanation": "ok"})
    corrected = client.post("/v1/correct", json={"text": "Ich gehe."})
    assert corrected.status_code == 200 and corrected.json()["correct"] is True


# ----------------------------------------------------------- concurrency

def test_limiter_refuses_when_full_and_frees_the_slot():
    limiter = InferenceLimiter(slots=1, wait_seconds=0)
    with limiter.slot():
        with pytest.raises(Busy):
            with limiter.slot():
                pass
    with limiter.slot():
        pass


def test_a_busy_server_answers_503_with_retry_after(client, monkeypatch):
    limiter = InferenceLimiter(slots=1, wait_seconds=0)
    monkeypatch.setattr(main, "inference_limiter", limiter)
    provider(monkeypatch, lambda *a: {"reply": "Hallo!", "followUp": "?"})
    with limiter.slot():
        response = chat(client)
    assert response.status_code == 503
    assert response.headers["retry-after"] == "5"
    assert chat(client).status_code == 200


def test_transcription_runs_off_the_event_loop_and_obeys_the_limit(client, monkeypatch):
    here = str(Path(__file__))
    monkeypatch.setattr(main, "WHISPER_CPP_BIN", here)
    monkeypatch.setattr(main, "WHISPER_MODEL_PATH", here)
    threads = []

    class Done:
        returncode = 0
        stdout = "Guten Tag"
        stderr = ""

    def run(*a, **k):
        threads.append(threading.current_thread())
        return Done()

    monkeypatch.setattr(main.subprocess, "run", run)
    limiter = InferenceLimiter(slots=1, wait_seconds=0)
    monkeypatch.setattr(main, "inference_limiter", limiter)

    files = {"audio": ("c.wav", WAV, "audio/wav")}
    assert client.post("/v1/transcribe", files=files).status_code == 200
    assert threads and threads[0] is not threading.main_thread()
    with limiter.slot():
        assert client.post("/v1/transcribe", files=files).status_code == 503


# -------------------------------------------------------------- fallback

def test_fallback_provider_answers_when_the_first_is_down(client, monkeypatch):
    monkeypatch.setattr(main, "AI_FALLBACK_PROVIDER", "groq")
    calls = []

    def fake(name, *a):
        calls.append(name)
        if name == "ollama":
            raise HTTPException(status_code=503, detail="down")
        return {"reply": "Hallo!", "followUp": "Wie geht's?"}

    provider(monkeypatch, fake)
    assert chat(client).status_code == 200
    assert calls == ["ollama", "groq"]


def test_no_fallback_for_a_caller_error_or_when_not_configured(client, monkeypatch):
    calls = []

    def fail(status):
        def fake(name, *a):
            calls.append(name)
            raise HTTPException(status_code=status, detail="x")
        return fake

    monkeypatch.setattr(main, "AI_FALLBACK_PROVIDER", "groq")
    provider(monkeypatch, fail(400))
    assert chat(client).status_code == 400 and calls == ["ollama"]

    calls.clear()
    monkeypatch.setattr(main, "AI_FALLBACK_PROVIDER", "")
    provider(monkeypatch, fail(503))
    assert chat(client).status_code == 503 and calls == ["ollama"]


def test_both_providers_down_returns_the_last_error(client, monkeypatch):
    monkeypatch.setattr(main, "AI_FALLBACK_PROVIDER", "groq")
    provider(monkeypatch, lambda *a: (_ for _ in ()).throw(HTTPException(status_code=503, detail="x")))
    assert chat(client).status_code == 503


# ------------------------------------------------------------ request ids

def test_request_ids(client, monkeypatch):
    provider(monkeypatch, lambda *a: {"reply": "x", "followUp": "y"})
    sent = client.post("/v1/chat", json={"message": "Hallo"}, headers={"X-Request-ID": "abc-12345678"})
    assert sent.headers["x-request-id"] == "abc-12345678"
    bad = client.post("/v1/chat", json={"message": "Hallo"}, headers={"X-Request-ID": "x\ninjected"})
    assert bad.headers["x-request-id"] != "x\ninjected" and len(bad.headers["x-request-id"]) == 16
    assert request_id(None) != request_id(None)
    assert client.post("/v1/chat", content=b"x" * 70000, headers={"Content-Type": "application/json"}).headers["x-request-id"]


def test_requests_are_logged_without_bodies(client, monkeypatch, caplog):
    provider(monkeypatch, lambda *a: {"reply": "x", "followUp": "y"})
    with caplog.at_level("INFO", logger="sprichst"):
        client.post("/v1/chat", json={"message": "mein geheimer satz"})
    text = caplog.text
    assert "POST /v1/chat status=200" in text and "provider=" in text
    assert "geheimer" not in text


# --------------------------------------------------------------- readiness

def test_readiness_reflects_the_provider_and_hides_details(client, monkeypatch):
    main._ready_cache.update(at=0.0, ok=False)

    def down(*a, **k):
        raise OSError("refused")

    monkeypatch.setattr(main, "urlopen", down)
    response = client.get("/health/ready")
    assert response.status_code == 503 and response.json() == {"status": "degraded"}

    main._ready_cache.update(at=0.0, ok=False)

    class Ok:
        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    monkeypatch.setattr(main, "urlopen", lambda *a, **k: Ok())
    response = client.get("/health/ready")
    assert response.status_code == 200 and response.json() == {"status": "ready"}
    assert client.get("/health").json() == {"status": "ok"}
