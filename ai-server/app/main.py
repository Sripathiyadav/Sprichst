"""
Sprichst AI Gateway.

The Flutter client calls this service instead of Ollama directly.

Text generation can use Groq/Qwen or local Ollama depending on
AI_PROVIDER. Whisper transcription and macOS TTS remain local.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parents[2]

load_dotenv(
    BASE_DIR / "ai-server" / ".env",
    override=True,
)


# ---------------------------------------------------------------------------
# AI configuration
# ---------------------------------------------------------------------------

AI_PROVIDER = os.getenv(
    "AI_PROVIDER",
    "ollama",
).lower()

OLLAMA_BASE_URL = os.getenv(
    "OLLAMA_BASE_URL",
    "http://127.0.0.1:11434",
)

OLLAMA_MODEL = os.getenv(
    "OLLAMA_MODEL",
    "qwen2.5:0.5b-instruct",
)

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

GROQ_BASE_URL = os.getenv(
    "GROQ_BASE_URL",
    "https://api.groq.com/openai/v1",
)

GROQ_MODEL = os.getenv(
    "GROQ_MODEL",
    "qwen/qwen3.8-27b",
)

MAX_TEXT_LENGTH = 1500


# ---------------------------------------------------------------------------
# Local speech configuration
# ---------------------------------------------------------------------------

WHISPER_CPP_BIN = os.getenv(
    "WHISPER_CPP_BIN",
    os.path.expanduser(
        "~/Developer/whisper.cpp/build/bin/whisper-cli"
    ),
)

WHISPER_MODEL_PATH = os.getenv(
    "WHISPER_MODEL_PATH",
    os.path.expanduser(
        "~/Developer/whisper.cpp/models/ggml-base.bin"
    ),
)

WHISPER_LANGUAGE = os.getenv(
    "WHISPER_LANGUAGE",
    "de",
)

TTS_VOICE = "Anna"
TTS_RATE = "200"


# ---------------------------------------------------------------------------
# FastAPI
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Sprichts AI Gateway",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------

class LearningContext(BaseModel):
    level: str = Field(
        default="A0 / Pre-A1",
        max_length=20,
    )

    current_unit: str | None = Field(
        default=None,
        max_length=100,
    )

    current_lesson: str | None = Field(
        default=None,
        max_length=100,
    )

    weak_skills: list[str] = Field(
        default_factory=list,
        max_length=8,
    )

    known_vocabulary: list[str] = Field(
        default_factory=list,
        max_length=30,
    )

    recent_mistakes: list[str] = Field(
        default_factory=list,
        max_length=10,
    )


class CorrectRequest(BaseModel):
    text: str = Field(
        min_length=1,
        max_length=MAX_TEXT_LENGTH,
    )

    context: LearningContext = Field(
        default_factory=LearningContext,
    )


class ChatRequest(BaseModel):
    message: str = Field(
        min_length=1,
        max_length=MAX_TEXT_LENGTH,
    )

    context: LearningContext = Field(
        default_factory=LearningContext,
    )


# ---------------------------------------------------------------------------
# Shared AI prompt
# ---------------------------------------------------------------------------

def _system_prompt(context: LearningContext) -> str:
    """Build the shared system prompt for AI providers."""

    context_json = json.dumps(
        context.model_dump(),
        ensure_ascii=False,
    )

    return f"""
You are Sprichts, a careful German tutor.

The learner is at {context.level}.

Use short, level-appropriate explanations.
Do not invent grammar rules or claim certainty when unsure.
Correct errors before suggesting stylistic changes.

The trusted learner context is:

{context_json}

Return valid JSON only, with no Markdown.
Keep vocabulary beginner-friendly unless the context explicitly
supports a higher level.
""".strip()


# ---------------------------------------------------------------------------
# Local Ollama provider
# ---------------------------------------------------------------------------

def _ollama_json(
    user_prompt: str,
    context: LearningContext,
    schema_hint: str,
) -> dict[str, Any]:

    payload = {
        "model": OLLAMA_MODEL,
        "stream": False,
        "format": "json",
        "messages": [
            {
                "role": "system",
                "content": (
                    f"{_system_prompt(context)}\n"
                    f"Required JSON shape: {schema_hint}"
                ),
            },
            {
                "role": "user",
                "content": user_prompt,
            },
        ],
        "options": {
            "temperature": 0.2,
        },
    }

    request = Request(
        f"{OLLAMA_BASE_URL.rstrip('/')}/api/chat",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(
            request,
            timeout=45,
        ) as response:
            body = json.loads(
                response.read().decode("utf-8")
            )

    except (URLError, TimeoutError, OSError) as error:
        raise HTTPException(
            status_code=503,
            detail=(
                "Ollama is unavailable. "
                "Start it and make sure the configured model exists."
            ),
        ) from error

    try:
        content = body["message"]["content"]
        return json.loads(content)

    except (
        KeyError,
        TypeError,
        json.JSONDecodeError,
    ) as error:
        raise HTTPException(
            status_code=502,
            detail="The Ollama model returned invalid structured data.",
        ) from error


# ---------------------------------------------------------------------------
# Groq / Qwen provider
# ---------------------------------------------------------------------------

def _groq_json(
    user_prompt: str,
    context: LearningContext,
    schema_hint: str,
) -> dict[str, Any]:

    if not GROQ_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GROQ_API_KEY is not configured.",
        )

    payload = {
        "model": GROQ_MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    f"{_system_prompt(context)}\n"
                    f"Required JSON shape: {schema_hint}"
                ),
            },
            {
                "role": "user",
                "content": user_prompt,
            },
        ],
        "temperature": 0.2,
        "response_format": {
            "type": "json_object",
        },
    }

    request = Request(
        f"{GROQ_BASE_URL.rstrip('/')}/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {GROQ_API_KEY}",
            "User-Agent": "curl/8.0",
        },
        method="POST",
    )

    try:
        with urlopen(
            request,
            timeout=45,
        ) as response:
            body = json.loads(
                response.read().decode("utf-8")
            )

    except (URLError, TimeoutError, OSError) as error:
        raise HTTPException(
            status_code=503,
            detail="Groq is unavailable.",
        ) from error

    try:
        content = body["choices"][0]["message"]["content"]
        return json.loads(content)

    except (
        KeyError,
        IndexError,
        TypeError,
        json.JSONDecodeError,
    ) as error:
        raise HTTPException(
            status_code=502,
            detail="Groq returned invalid structured data.",
        ) from error


# ---------------------------------------------------------------------------
# Provider router
# ---------------------------------------------------------------------------

def _ai_json(
    user_prompt: str,
    context: LearningContext,
    schema_hint: str,
) -> dict[str, Any]:

    if AI_PROVIDER == "groq":
        return _groq_json(
            user_prompt,
            context,
            schema_hint,
        )

    if AI_PROVIDER == "ollama":
        return _ollama_json(
            user_prompt,
            context,
            schema_hint,
        )

    raise HTTPException(
        status_code=500,
        detail=(
            f"Unsupported AI_PROVIDER '{AI_PROVIDER}'. "
            "Use 'groq' or 'ollama'."
        ),
    )


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
def health() -> dict[str, str]:
    """Lightweight service check."""

    return {
        "status": "ok",
        "provider": AI_PROVIDER,
        "model": (
            GROQ_MODEL
            if AI_PROVIDER == "groq"
            else OLLAMA_MODEL
        ),
    }


# ---------------------------------------------------------------------------
# Whisper transcription
# ---------------------------------------------------------------------------

@app.post("/v1/transcribe")
async def transcribe(
    audio: UploadFile = File(...),
) -> dict[str, str]:
    """Transcribe uploaded audio locally with whisper.cpp."""

    if not Path(WHISPER_CPP_BIN).is_file():
        raise HTTPException(
            status_code=500,
            detail="whisper.cpp executable was not found.",
        )

    if not Path(WHISPER_MODEL_PATH).is_file():
        raise HTTPException(
            status_code=500,
            detail="Whisper model was not found.",
        )

    suffix = Path(
        audio.filename or ""
    ).suffix.lower()

    if suffix not in {
        ".mp3",
        ".wav",
        ".m4a",
        ".ogg",
        ".flac",
    }:
        raise HTTPException(
            status_code=400,
            detail="Unsupported audio format.",
        )

    audio_bytes = await audio.read()

    if not audio_bytes:
        raise HTTPException(
            status_code=400,
            detail="The uploaded audio file is empty.",
        )

    if len(audio_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="Audio file is too large. Maximum size is 10 MB.",
        )

    with tempfile.TemporaryDirectory() as temp_dir:

        input_path = Path(temp_dir) / f"input{suffix}"

        input_path.write_bytes(audio_bytes)

        command = [
            WHISPER_CPP_BIN,
            "--model",
            WHISPER_MODEL_PATH,
            "--language",
            WHISPER_LANGUAGE,
            "--no-timestamps",
            "--no-prints",
            str(input_path),
        ]

        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=60,
                check=False,
            )

        except subprocess.TimeoutExpired as error:
            raise HTTPException(
                status_code=504,
                detail="Speech transcription timed out.",
            ) from error

        except OSError as error:
            raise HTTPException(
                status_code=500,
                detail="Could not start whisper.cpp.",
            ) from error

        if result.returncode != 0:
            raise HTTPException(
                status_code=502,
                detail="Whisper transcription failed.",
            )

        text = result.stdout.strip()

        if not text:
            raise HTTPException(
                status_code=422,
                detail="No speech was detected.",
            )

        return {
            "text": text,
            "language": WHISPER_LANGUAGE,
        }


# ---------------------------------------------------------------------------
# German correction
# ---------------------------------------------------------------------------

@app.post("/v1/correct")
def correct(
    request: CorrectRequest,
) -> dict[str, Any]:

    return _ai_json(
        f"""
Analyze this German sentence as a German language tutor.

Sentence:

{request.text}

Learner level:

{request.context.level}

Follow these rules carefully:

1. First decide whether the sentence is grammatically correct.

2. If it is correct:
   - "correct" must be true.
   - "corrected" must be exactly the original sentence.
   - "mistakes" must be an empty list.
   - "explanation" must briefly say that the sentence is grammatically correct.

3. If it is incorrect:
   - Correct only the actual grammatical or vocabulary mistakes.
   - Preserve the original meaning and wording wherever possible.
   - Do not rewrite a sentence simply because another version sounds more natural.

4. For every mistake, identify the exact incorrect text in "value"
   and its exact replacement in "correction".

5. Explain ONLY the mistake that you actually identified.

6. Do not invent grammar rules.

7. Do not describe the sentence using a tense or grammar concept
   unless that concept is relevant to the actual mistake.

8. Use simple language appropriate for the learner's level.

9. Do not change a correct verb tense.

10. Do not change "haben" to "sein" unless the verb actually requires
    "sein" in the intended construction.

11. Do not change articles, prepositions, cases, or word order unless
    they are actually incorrect.

12. The explanation must directly correspond to the entries in "mistakes".

13. Return valid JSON only. Do not return Markdown.

Examples:

Sentence:
"Ich gehe morgen zur Arbeit."

This is correct. Do not change it to another tense.

Sentence:
"Ich gehen morgen zur Arbeit."

Corrected:
"Ich gehe morgen zur Arbeit."

Mistake:
"gehen" → "gehe"

Explanation:
"Nach 'ich' wird das Verb 'gehen' zu 'gehe'."

Sentence:
"Ich wohne hier seit zwei Jahre."

Corrected:
"Ich wohne hier seit zwei Jahren."

Mistake:
"seit zwei Jahre" → "seit zwei Jahren"

Explanation:
"Nach 'seit' steht hier der Dativ: 'zwei Jahren'."
""",
        request.context,
        """
{
  "correct": boolean,
  "original": string,
  "corrected": string,
  "explanation": string,
  "level": string,
  "mistakes": [
    {
      "category": string,
      "value": string,
      "correction": string
    }
  ],
  "followUp": string
}
""",
    )


# ---------------------------------------------------------------------------
# German tutor chat
# ---------------------------------------------------------------------------

@app.post("/v1/chat")
def chat(
    request: ChatRequest,
) -> dict[str, Any]:

    return _ai_json(
        f"""
You are having a German-learning conversation with the learner.

Learner message:

{request.message}

Tutor rules:

1. You are a German language tutor having a natural conversation
   with a learner.

2. Use German appropriate for the learner's CEFR level:
   {request.context.level}

3. Prefer simple German vocabulary and sentence structures.

4. Keep the conversation natural and concise.

5. Carefully check the learner's sentence for actual mistakes in:
   - grammar
   - spelling
   - word order
   - articles
   - grammatical case
   - noun endings
   - adjective endings
   - verb conjugation
   - vocabulary

   If an actual mistake exists, you MUST correct it.

6. Pay special attention to grammatical endings.

   A sentence can have the correct preposition and still contain a
   grammatical case error in the following noun, article, adjective,
   or ending.

   Do not mark a sentence as correct merely because the preposition
   itself is correct.

7. NEVER put an explanation, grammar rule, or description of the mistake
   inside the "correction" field.

8. The "explanation" field MUST be in ENGLISH and briefly explain:
   - what the learner did wrong
   - what the correct form is
   - why the correction is needed

9. If the learner's sentence is already completely correct:
   - "correction" MUST be null
   - "explanation" MUST be null
   - Do NOT explain why it is correct.
   - Do NOT mention any grammar rule.
   - The only feedback about correctness should be in the German "reply" field.

10. Never invent a correction.

11. Never rewrite a correct sentence merely because another phrasing
    sounds more natural.

12. After correcting the learner, continue the conversation naturally
    in German.

13. Ask exactly ONE simple follow-up question in German.

14. Keep the response concise because it may later be spoken aloud.

15. Return ONLY the requested JSON object.

IMPORTANT EXAMPLE 1 — GRAMMAR MISTAKE:

Learner:
"Ich gehen morgen zur Arbeit."

The learner already used the pronoun "ich".

The mistake is the verb conjugation:

"ich gehen" → "ich gehe"

The correction MUST be:

"Ich gehe morgen zur Arbeit."

The explanation MUST be in English, for example:

"With 'ich', the verb 'gehen' becomes 'gehe'."

The response should look like:

{{
  "reply": "Fast richtig!",
  "correction": "Ich gehe morgen zur Arbeit.",
  "explanation": "With 'ich', the verb 'gehen' becomes 'gehe'.",
  "followUp": "Wann gehst du zur Arbeit?"
}}

IMPORTANT EXAMPLE 2 — CASE MISTAKE:

Learner:
"Ich wohne hier seit zwei Jahre."

The mistake is:

"seit zwei Jahre" → "seit zwei Jahren"

The correction MUST be:

"Ich wohne hier seit zwei Jahren."

The explanation should be:

"After 'seit', we use the dative. 'zwei Jahre' becomes 'zwei Jahren'."

IMPORTANT EXAMPLE 3 — CORRECT SENTENCE:

Learner:
"Ich gehe morgen zur Arbeit."

The sentence is correct.

The response should contain:

{{
  "reply": "Sehr gut!",
  "correction": null,
  "explanation": null,
  "followUp": "Was machst du morgen?"
}}

IMPORTANT EXAMPLE 4 — CASE ENDING MISTAKE:

Learner:
"Ich wohne hier seit zwei Jahre."

This sentence contains a grammatical mistake.

The incorrect phrase is:

"seit zwei Jahre"

The correct phrase is:

"seit zwei Jahren"

The correction MUST be:

"Ich wohne hier seit zwei Jahren."

The explanation MUST explain the actual mistake:

"After 'seit', the phrase is in the dative. 'zwei Jahre' becomes 'zwei Jahren'."

Do NOT say that "seit" is incorrect.
Do NOT say that the learner used the wrong preposition.
Do NOT mark this sentence as correct.

IMPORTANT EXAMPLE 5 — AKKUSATIV ARTICLE MISTAKE:

Learner:
"Ich habe ein Hund."

This sentence contains a grammatical case mistake.

The incorrect phrase is:

"ein Hund"

The correct phrase is:

"einen Hund"

The correction MUST be:

"Ich habe einen Hund."

The explanation MUST say that "Hund" is masculine and is the direct object of "haben", so it is in the accusative:

"With 'haben', the object is in the accusative. For masculine nouns, 'ein' becomes 'einen'."

Do NOT say that the learner forgot the article.
Do NOT say that "ein" is missing.

The learner's current lesson is:

{request.context.current_lesson}

The learner's weak skills are:

{request.context.weak_skills}
""",
        request.context,
        """
{
  "reply": string,
  "correction": string|null,
  "explanation": string|null,
  "followUp": string
}
""",
    )


# ---------------------------------------------------------------------------
# Local macOS TTS
# ---------------------------------------------------------------------------

@app.post("/v1/speak")
def speak(
    request: ChatRequest,
) -> Response:

    text = request.message.strip()

    if not text:
        raise HTTPException(
            status_code=400,
            detail="Speech text cannot be empty.",
        )

    with tempfile.TemporaryDirectory(
        prefix="sprichst_tts_",
    ) as temp_dir:

        temp_path = Path(temp_dir)

        aiff_path = temp_path / "speech.aiff"
        wav_path = temp_path / "speech.wav"

        try:
            say_result = subprocess.run(
                [
                    "/usr/bin/say",
                    "-v",
                    TTS_VOICE,
                    "-r",
                    TTS_RATE,
                    "-o",
                    str(aiff_path),
                    text,
                ],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )

        except subprocess.TimeoutExpired as error:
            raise HTTPException(
                status_code=504,
                detail="Speech synthesis timed out.",
            ) from error

        except OSError as error:
            raise HTTPException(
                status_code=500,
                detail="Could not start macOS speech synthesis.",
            ) from error

        if say_result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=(
                    "macOS speech synthesis failed: "
                    f"{say_result.stderr.strip()}"
                ),
            )

        if (
            not aiff_path.exists()
            or aiff_path.stat().st_size == 0
        ):
            raise HTTPException(
                status_code=500,
                detail="Speech synthesis did not produce an AIFF file.",
            )

        convert_command = [
            "/usr/bin/afconvert",
            "-f",
            "WAVE",
            "-d",
            "LEI16@16000",
            str(aiff_path),
            str(wav_path),
        ]

        try:
            convert_result = subprocess.run(
                convert_command,
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )

        except subprocess.TimeoutExpired as error:
            raise HTTPException(
                status_code=504,
                detail="Audio conversion timed out.",
            ) from error

        except OSError as error:
            raise HTTPException(
                status_code=500,
                detail="Could not start audio conversion.",
            ) from error

        if convert_result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=(
                    "Audio conversion failed: "
                    f"{convert_result.stderr.strip()}"
                ),
            )

        if (
            not wav_path.exists()
            or wav_path.stat().st_size == 0
        ):
            raise HTTPException(
                status_code=500,
                detail="Speech synthesis produced an empty audio file.",
            )

        return Response(
            content=wav_path.read_bytes(),
            media_type="audio/wav",
            headers={
                "Content-Disposition": (
                    "inline; filename=speech.wav"
                ),
            },
        )