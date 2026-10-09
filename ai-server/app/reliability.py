"""Keeping the gateway healthy under load and honest about model output.

* [InferenceLimiter] caps how many model, speech or synthesis jobs run at once,
  so a burst of requests queues briefly and then gets a clear "busy" answer
  instead of exhausting memory or the provider budget.
* [parse_chat] and [parse_correction] check what a model returned before it
  reaches the app: valid JSON is not enough, the fields have to be there and be
  the right type.
* [request_id] accepts a caller's id or makes one, for log correlation.
"""

from __future__ import annotations

import re
import threading
import uuid
from contextlib import contextmanager
from typing import Any, Iterator, Optional

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator


class Busy(Exception):
    """No inference slot became free in time."""


class InferenceLimiter:
    def __init__(self, slots: int, wait_seconds: float) -> None:
        self.slots = max(1, slots)
        self.wait_seconds = max(0.0, wait_seconds)
        self._semaphore = threading.BoundedSemaphore(self.slots)

    @contextmanager
    def slot(self) -> Iterator[None]:
        if not self._semaphore.acquire(timeout=self.wait_seconds):
            raise Busy()
        try:
            yield
        finally:
            self._semaphore.release()


# --------------------------------------------------------------- request ids

_ID = re.compile(r"^[A-Za-z0-9\-]{8,64}$")


def request_id(incoming: Optional[str]) -> str:
    """The caller's id when it looks like one, else a new short id."""
    if incoming and _ID.match(incoming):
        return incoming
    return uuid.uuid4().hex[:16]


# ----------------------------------------------------------- model output

class ModelOutputError(Exception):
    """The model answered, but not in the shape the app relies on."""


def _optional_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError("expected text")
    value = value.strip()
    return value or None


class _Result(BaseModel):
    model_config = ConfigDict(extra="ignore")  # unknown fields are dropped


class ChatResult(_Result):
    reply: str = Field(default="", max_length=1500)
    correction: Optional[str] = Field(default=None, max_length=1500)
    explanation: Optional[str] = Field(default=None, max_length=1500)
    followUp: str = Field(default="", max_length=500)

    @field_validator("correction", "explanation", mode="before")
    @classmethod
    def _text_or_null(cls, value: Any) -> Optional[str]:
        return _optional_text(value)

    @field_validator("reply", "followUp", mode="before")
    @classmethod
    def _text(cls, value: Any) -> str:
        return _optional_text(value) or ""


class Mistake(_Result):
    category: str = Field(default="", max_length=60)
    value: str = Field(default="", max_length=300)
    correction: str = Field(default="", max_length=300)

    @field_validator("category", "value", "correction", mode="before")
    @classmethod
    def _text(cls, value: Any) -> str:
        return _optional_text(value) or ""


class CorrectionResult(_Result):
    correct: Optional[bool] = None
    original: str = Field(default="", max_length=1500)
    corrected: str = Field(max_length=1500)
    explanation: str = Field(default="", max_length=1500)
    level: str = Field(default="", max_length=30)
    mistakes: list[Mistake] = Field(default_factory=list, max_length=20)
    followUp: str = Field(default="", max_length=500)

    @field_validator("original", "explanation", "level", "followUp", mode="before")
    @classmethod
    def _text(cls, value: Any) -> str:
        return _optional_text(value) or ""

    @field_validator("corrected", mode="before")
    @classmethod
    def _required_text(cls, value: Any) -> str:
        text = _optional_text(value)
        if not text:
            raise ValueError("a corrected sentence is required")
        return text

    @field_validator("mistakes", mode="before")
    @classmethod
    def _list(cls, value: Any) -> Any:
        return [] if value is None else value


def _check(model: type[BaseModel], data: Any) -> dict[str, Any]:
    if not isinstance(data, dict):
        raise ModelOutputError("the model did not return an object")
    try:
        return model.model_validate(data).model_dump()
    except ValidationError as error:
        raise ModelOutputError(str(error.errors()[0]["loc"])) from error


def parse_chat(data: Any) -> dict[str, Any]:
    result = _check(ChatResult, data)
    if not result["reply"] and not result["followUp"]:
        raise ModelOutputError("the model returned no reply")
    return result


def parse_correction(data: Any, original: str) -> dict[str, Any]:
    result = _check(CorrectionResult, data)
    result["original"] = result["original"] or original
    if result["correct"] is None:
        result["correct"] = result["corrected"].strip() == original.strip()
    return result
