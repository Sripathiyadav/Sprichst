"""Validate curriculum/course.json before publishing content.

Mirrors the checks in lib/data/curriculum_parser.dart so mistakes are caught in
review or CI instead of when the app starts.
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

COURSE = Path(__file__).resolve().parents[1] / "curriculum" / "course.json"

LEVELS = {"preA1", "a1", "a2", "b1", "b2", "c1"}
KINDS = {"multipleChoice", "fillBlank", "translation", "wordOrder"}
AREAS = {"vocabulary", "grammar", "reading", "listening", "writing", "speaking"}
LESSON_TEXT = ("id", "unit", "title", "objective", "introduction")
EXERCISE_TEXT = ("id", "prompt", "answer", "explanation")


def check_exercise(lesson_id: str, exercise: dict) -> list[str]:
    where = f"{lesson_id}/{exercise.get('id', '?')}"
    errors = [
        f"{where}: '{key}' must be non-empty text"
        for key in EXERCISE_TEXT
        if not isinstance(exercise.get(key), str) or not exercise[key].strip()
    ]
    if exercise.get("kind") not in KINDS:
        errors.append(f"{where}: kind must be one of {sorted(KINDS)}")
    if exercise.get("area") not in AREAS:
        errors.append(f"{where}: area must be one of {sorted(AREAS)}")
    skills = exercise.get("skills")
    if not isinstance(skills, list) or not skills:
        errors.append(f"{where}: needs at least one skill")

    options = exercise.get("options", [])
    answers = [exercise.get("answer", ""), *exercise.get("alternatives", [])]
    if exercise.get("kind") == "multipleChoice" and exercise.get("answer") not in options:
        errors.append(f"{where}: answer must be one of the options")
    if exercise.get("kind") == "wordOrder":
        bank = sorted(options)
        for answer in answers:
            if sorted(str(answer).split(" ")) != bank:
                errors.append(f"{where}: '{answer}' must use exactly the word bank")
    return errors


def main() -> int:
    try:
        lessons = json.loads(COURSE.read_text(encoding="utf-8"))["lessons"]
    except (OSError, KeyError, json.JSONDecodeError) as error:
        print(f"Curriculum validation failed: cannot read {COURSE.name} ({error})")
        return 1

    errors: list[str] = []
    for lesson in lessons:
        lesson_id = lesson.get("id", "?")
        errors += [
            f"{lesson_id}: '{key}' must be non-empty text"
            for key in LESSON_TEXT
            if not isinstance(lesson.get(key), str) or not lesson[key].strip()
        ]
        if lesson.get("level") not in LEVELS:
            errors.append(f"{lesson_id}: level must be one of {sorted(LEVELS)}")
        if not lesson.get("examples"):
            errors.append(f"{lesson_id}: examples must be a non-empty list")
        if not lesson.get("exercises"):
            errors.append(f"{lesson_id}: needs at least one exercise")
        for exercise in lesson.get("exercises", []):
            errors += check_exercise(lesson_id, exercise)

    lesson_ids = Counter(lesson.get("id") for lesson in lessons)
    exercise_ids = Counter(e.get("id") for l in lessons for e in l.get("exercises", []))
    for kind, counter in (("lesson", lesson_ids), ("exercise", exercise_ids)):
        errors += [f"duplicate {kind} id '{key}'" for key, n in counter.items() if n > 1]

    if errors:
        print("Curriculum validation failed:")
        print("\n".join(f"- {message}" for message in errors))
        return 1
    print(f"Curriculum valid: {len(lessons)} lessons, {sum(exercise_ids.values())} exercises.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
