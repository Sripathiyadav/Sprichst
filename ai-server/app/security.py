"""Input validation, abuse limits and authentication for the Sprichst gateway.

Everything here is independent of the model providers so it can be tested alone.

What it protects against:

* Oversized or malformed input: every string is length-limited, stripped of
  control characters and Unicode-normalised before it can reach a prompt, a
  subprocess or a log line. Uploads are checked by their real signature, not
  only by file name.
* Abuse and cost: a per-client rate limit and a request-size cap.
* Anonymous use: optional verification of Firebase ID tokens (AUTH_REQUIRED=1).
* Leaking internals: handlers return short, fixed messages; details go to the
  server log.

There is no SQL anywhere in the gateway and nothing here builds a query from
user input. If a database is ever added, use parameterised statements only
(see SECURITY.md); tests/test_no_raw_sql.py enforces that no SQL is assembled
from strings.
"""

from __future__ import annotations

import logging
import re
import threading
import time
import unicodedata
from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Annotated, Any, Callable, Optional

from pydantic import AfterValidator, StringConstraints

log = logging.getLogger("sprichst.security")

# --------------------------------------------------------------------- text

# Control characters other than tab and newline have no place in learner text,
# nor do invisible format characters (zero-width, bidirectional overrides, BOM).
# Unicode categories Cc and Cf cover exactly those, without writing any
# invisible character into this source file.
_REMOVED_CATEGORIES = {"Cc", "Cf"}
_MANY_BLANK_LINES = re.compile(r"\n{4,}")


def clean_text(value: str) -> str:
    """NFC-normalise, drop control and invisible direction characters, trim."""
    value = unicodedata.normalize("NFC", value)
    value = "".join(
        ch
        for ch in value
        if ch in "\n\t" or unicodedata.category(ch) not in _REMOVED_CATEGORIES
    )
    value = _MANY_BLANK_LINES.sub("\n\n\n", value)
    return value.strip()


def _text(max_length: int, min_length: int = 0):
    return Annotated[
        str,
        StringConstraints(max_length=max_length, min_length=min_length),
        AfterValidator(clean_text),
    ]


Short = _text(60)  # a skill id, a word
Medium = _text(120)  # a unit or lesson title, a mistake summary
Message = _text(1500, min_length=1)  # what the learner typed or said
Turn = _text(500, min_length=1)  # one earlier line of the conversation

# A CEFR level label such as "A1", "B2" or "A0 / Pre-A1". It is placed into the
# model's instructions, so it is restricted to the characters such labels use.
LEVEL_PATTERN = r"^[A-Za-z0-9 /().+\-]{1,30}$"

# A voice id ("de_DE-thorsten-medium") or an older system voice name ("Anna").
VOICE_PATTERN = r"^[A-Za-z0-9 _.()\-]{1,80}$"


# -------------------------------------------------------------------- uploads

MAX_AUDIO_BYTES = 10 * 1024 * 1024
AUDIO_SUFFIXES = {".mp3", ".wav", ".m4a", ".ogg", ".flac"}


def looks_like_audio(data: bytes) -> bool:
    """Whether [data] starts like one of the audio formats we accept.

    A file named .wav that is really an executable or an HTML page is refused
    before it is written to disk or handed to a decoder.
    """
    head = data[:16]
    if head[:4] == b"RIFF" and head[8:12] == b"WAVE":
        return True
    if head[:3] == b"ID3" or (len(head) > 1 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0):
        return True  # MP3 (tagged, or raw frame sync)
    if head[:4] == b"OggS" or head[:4] == b"fLaC":
        return True
    if head[4:8] == b"ftyp":
        return True  # MP4 / M4A
    return False


# ----------------------------------------------------------------- rate limit

class RateLimiter:
    """A sliding-window limit per client key, kept in memory.

    Good enough for one server process; use a shared store (Redis, an API
    gateway) if the service is ever scaled out.
    """

    def __init__(
        self,
        limit: int,
        window_seconds: float = 60.0,
        clock: Callable[[], float] = time.monotonic,
        max_clients: int = 10_000,
    ) -> None:
        self.limit = limit
        self.window = window_seconds
        self._clock = clock
        self._max_clients = max_clients
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, key: str) -> Optional[int]:
        """None if the request may go ahead, else seconds until it may."""
        now = self._clock()
        with self._lock:
            hits = self._hits[key]
            while hits and now - hits[0] >= self.window:
                hits.popleft()
            if len(hits) >= self.limit:
                return max(1, int(self.window - (now - hits[0])) + 1)
            hits.append(now)
            if len(self._hits) > self._max_clients:
                self._evict(now)
            return None

    def _evict(self, now: float) -> None:
        for key in [k for k, v in self._hits.items() if not v or now - v[-1] >= self.window]:
            del self._hits[key]


# ------------------------------------------------------------- authentication

class AuthError(Exception):
    """The caller is not allowed in. The message is safe to show them."""


@dataclass(frozen=True)
class Caller:
    """Who is calling: a verified learner, or an anonymous address."""

    key: str
    uid: Optional[str] = None


GOOGLE_CERTS_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/"
    "securetoken@system.gserviceaccount.com"
)


class FirebaseTokenVerifier:
    """Verifies Firebase Auth ID tokens (RS256 JWTs signed by Google).

    Follows Google's documented checks: signature against the current public
    certificates, `aud` = the project id, `iss` = securetoken.google.com/<id>,
    not expired, and a non-empty `sub`.
    """

    def __init__(
        self,
        project_id: str,
        fetch_certs: Optional[Callable[[], tuple[dict[str, str], float]]] = None,
        clock: Callable[[], float] = time.time,
    ) -> None:
        if not project_id:
            raise ValueError("FIREBASE_PROJECT_ID is required to verify tokens.")
        self.project_id = project_id
        self._fetch = fetch_certs or _fetch_google_certs
        self._clock = clock
        self._certs: dict[str, str] = {}
        self._expires = 0.0
        self._lock = threading.Lock()

    def _certificates(self) -> dict[str, str]:
        with self._lock:
            if not self._certs or self._clock() >= self._expires:
                certs, max_age = self._fetch()
                self._certs = certs
                self._expires = self._clock() + max_age
            return self._certs

    def verify(self, token: str) -> Caller:
        import jwt  # imported lazily: only needed when authentication is on
        from cryptography import x509

        if not token or len(token) > 8192 or token.count(".") != 2:
            raise AuthError("Sign in to use the AI tutor.")
        try:
            header = jwt.get_unverified_header(token)
        except jwt.PyJWTError as error:
            raise AuthError("Sign in again to use the AI tutor.") from error
        if header.get("alg") != "RS256":
            raise AuthError("Sign in again to use the AI tutor.")

        pem = self._certificates().get(header.get("kid", ""))
        if pem is None:
            raise AuthError("Sign in again to use the AI tutor.")
        public_key = x509.load_pem_x509_certificate(pem.encode()).public_key()

        try:
            claims: dict[str, Any] = jwt.decode(
                token,
                public_key,
                algorithms=["RS256"],
                audience=self.project_id,
                issuer=f"https://securetoken.google.com/{self.project_id}",
                options={"require": ["exp", "iat", "aud", "iss", "sub"]},
                leeway=30,
            )
        except jwt.ExpiredSignatureError as error:
            raise AuthError("Your session expired. Sign in again.") from error
        except jwt.PyJWTError as error:
            raise AuthError("Sign in again to use the AI tutor.") from error

        uid = claims.get("sub")
        if not isinstance(uid, str) or not uid or len(uid) > 128:
            raise AuthError("Sign in again to use the AI tutor.")
        return Caller(key=f"uid:{uid}", uid=uid)


def _fetch_google_certs() -> tuple[dict[str, str], float]:
    import json
    from urllib.request import Request, urlopen

    request = Request(GOOGLE_CERTS_URL, headers={"User-Agent": "sprichst-gateway"})
    with urlopen(request, timeout=10) as response:  # nosec: fixed, trusted HTTPS URL
        certs = json.loads(response.read().decode("utf-8"))
        cache = response.headers.get("Cache-Control", "")
    match = re.search(r"max-age=(\d+)", cache)
    return certs, float(match.group(1)) if match else 3600.0


def bearer_token(header: Optional[str]) -> Optional[str]:
    if not header:
        return None
    scheme, _, value = header.partition(" ")
    return value.strip() if scheme.lower() == "bearer" and value.strip() else None
