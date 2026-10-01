"""Sprichst AI gateway.

The Flutter client must call this authenticated HTTPS service, never Ollama
directly. In production, put Firebase ID-token verification and rate limiting
in front of the route handlers before enabling public traffic.
"""

from __future__ import annotations

import json
import os
from typing import Any, Literal
from urllib.error import URLError
from urllib.request import Request, urlopen

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://127.0.0.1:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:0.5b-instruct")
MAX_TEXT_LENGTH = 1500

app = FastAPI(title="Sprichst AI Gateway", version="0.1.0")


class LearningContext(BaseModel):
    level: str = Field(default="A0 / Pre-A1", max_length=20)
    current_unit: str | None = Field(default=None, max_length=100)
    current_lesson: str | None = Field(default=None, max_length=100)
    weak_skills: list[str] = Field(default_factory=list, max_length=8)
    known_vocabulary: list[str] = Field(default_factory=list, max_length=30)
    recent_mistakes: list[str] = Field(default_factory=list, max_length=10)


class CorrectRequest(BaseModel):
    text: str = Field(min_length=1, max_length=MAX_TEXT_LENGTH)
    context: LearningContext = Field(default_factory=LearningContext)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=MAX_TEXT_LENGTH)
    context: LearningContext = Field(default_factory=LearningContext)


class ExplainRequest(BaseModel):
    topic: str = Field(min_length=1, max_length=200)
    context: LearningContext = Field(default_factory=LearningContext)


class PracticeRequest(BaseModel):
    skill: str = Field(min_length=1, max_length=60)
    difficulty: str = Field(default="adaptive", max_length=30)
    context: LearningContext = Field(default_factory=LearningContext)


def _system_prompt(context: LearningContext) -> str:
    """Keep requests bounded, curriculum-aware, and schema-first."""
    context_json = json.dumps(context.model_dump(), ensure_ascii=False)
    return f"""You are Sprichst, a careful German tutor. The learner is at {context.level}.
Use only short, level-appropriate explanations. Do not invent grammar rules or
claim certainty when unsure. Correct errors before suggesting stylistic changes.
The trusted learner context is: {context_json}
Return valid JSON only, with no Markdown. Keep vocabulary beginner-friendly unless
the context explicitly supports a higher level."""


def _ollama_json(user_prompt: str, context: LearningContext, schema_hint: str) -> dict[str, Any]:
    payload = {
        "model": OLLAMA_MODEL,
        "stream": False,
        "format": "json",
        "messages": [
            {"role": "system", "content": f"{_system_prompt(context)}\nRequired JSON shape: {schema_hint}"},
            {"role": "user", "content": user_prompt},
        ],
        "options": {"temperature": 0.2},
    }
    request = Request(
        f"{OLLAMA_BASE_URL.rstrip('/')}/api/chat",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=45) as response:  # nosec B310: configured local endpoint
            body = json.loads(response.read().decode("utf-8"))
    except (URLError, TimeoutError, OSError) as error:
        raise HTTPException(status_code=503, detail="Ollama is unavailable. Start it and pull the configured model.") from error
    try:
        return json.loads(body["message"]["content"])
    except (KeyError, TypeError, json.JSONDecodeError) as error:
        raise HTTPException(status_code=502, detail="The model returned invalid structured data.") from error


@app.get("/health")
def health() -> dict[str, str]:
    """A lightweight reachability check that never starts a model."""
    try:
        with urlopen(f"{OLLAMA_BASE_URL.rstrip('/')}/api/tags", timeout=3) as response:  # nosec B310: configured local endpoint
            response.read(1)
        status = "available"
    except (URLError, TimeoutError, OSError):
        status = "unavailable"
    return {"status": "ok", "ollama": status, "model": OLLAMA_MODEL}


@app.post("/v1/correct")
def correct(request: CorrectRequest) -> dict[str, Any]:
    return _ollama_json(
        f"Correct this German sentence: {request.text}",
        request.context,
        '{"correct": boolean, "original": string, "corrected": string, "explanation": string, "level": string, "mistakes": [{"category": string, "value": string, "correction": string}], "followUp": string}',
    )


@app.post("/v1/chat")
def chat(request: ChatRequest) -> dict[str, Any]:
    return _ollama_json(
        request.message,
        request.context,
        '{"reply": string, "correction": string|null, "explanation": string|null, "followUp": string}',
    )


@app.post("/v1/explain")
def explain(request: ExplainRequest) -> dict[str, Any]:
    return _ollama_json(
        f"Explain the German grammar topic '{request.topic}' using a small rule and two examples.",
        request.context,
        '{"topic": string, "rule": string, "examples": [string], "commonMistake": string, "checkQuestion": string}',
    )


@app.post("/v1/practice")
def practice(request: PracticeRequest) -> dict[str, Any]:
    return _ollama_json(
        f"Create three {request.difficulty} {request.skill} questions. Include answers and explanations.",
        request.context,
        '{"skill": string, "level": string, "exercises": [{"prompt": string, "options": [string], "answer": string, "explanation": string}]}',
    )
