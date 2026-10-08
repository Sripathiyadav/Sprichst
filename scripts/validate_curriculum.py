"""Validate curriculum/course.json before publishing content.

Mirrors the checks in lib/data/curriculum_parser.dart so mistakes are caught in
review or CI instead of when the app starts.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

COURSE = Path(__file__).resolve().parents[1] / "curriculum" / "course.json"

LEVELS = {"preA1", "a1", "a2", "b1", "b2", "c1"}
KINDS = {
    "multipleChoice", "fillBlank", "translation", "wordOrder",
    "cloze", "listening", "writing", "speaking",
}
AREAS = {"vocabulary", "grammar", "reading", "listening", "writing", "speaking"}
GOALS = {"everyday", "travel", "work", "goethe", "testdaf"}
REGISTERS = {"informal", "formal", "essay"}
LESSON_TEXT = ("id", "unit", "title", "objective", "introduction")
EXERCISE_TEXT = ("id", "prompt", "answer", "explanation")


def text(value) -> bool:
    return isinstance(value, str) and bool(value.strip())


def check_exercise(lesson_id: str, exercise: dict) -> list[str]:
    where = f"{lesson_id}/{exercise.get('id', '?')}"
    kind = exercise.get("kind")
    errors = [f"{where}: '{k}' must be non-empty text" for k in EXERCISE_TEXT if not text(exercise.get(k))]
    if kind not in KINDS:
        errors.append(f"{where}: kind must be one of {sorted(KINDS)}")
    if exercise.get("area") not in AREAS:
        errors.append(f"{where}: area must be one of {sorted(AREAS)}")
    if not exercise.get("skills"):
        errors.append(f"{where}: needs at least one skill")
    if "difficulty" in exercise and exercise["difficulty"] not in (1, 2, 3):
        errors.append(f"{where}: difficulty must be 1, 2, or 3")

    options = exercise.get("options", [])
    answers = [exercise.get("answer", ""), *exercise.get("alternatives", [])]
    if kind in ("multipleChoice", "listening") and exercise.get("answer") not in options:
        errors.append(f"{where}: answer must be one of the options")
    if kind == "listening" and not text(exercise.get("audioText")):
        errors.append(f"{where}: a listening task needs audioText")
    if kind == "wordOrder":
        bank = sorted(options)
        for answer in answers:
            if sorted(str(answer).split(" ")) != bank:
                errors.append(f"{where}: '{answer}' must use exactly the word bank")
    if kind == "cloze":
        gaps = exercise.get("gaps", [])
        if not gaps:
            errors.append(f"{where}: a cloze needs at least one gap")
        for n, gap in enumerate(gaps, start=1):
            if gap.get("answer") not in gap.get("options", []):
                errors.append(f"{where}: gap {n} answer must be one of its options")
            if "{%d}" % n not in exercise.get("context", ""):
                errors.append(f"{where}: the passage must contain the marker {{{n}}}")
    if kind == "writing":
        brief = exercise.get("brief")
        if not brief:
            errors.append(f"{where}: a writing task needs a brief")
        else:
            if brief.get("register") not in REGISTERS:
                errors.append(f"{where}: brief register must be one of {sorted(REGISTERS)}")
            if not brief.get("points"):
                errors.append(f"{where}: a writing task needs content points")
            words = len(re.findall(r"[A-Za-zÄÖÜäöüß]+", exercise.get("answer", "")))
            if words < brief.get("minWords", 0):
                errors.append(f"{where}: the model answer has {words} words, under minWords")
    return errors


def main() -> int:
    try:
        course = json.loads(COURSE.read_text(encoding="utf-8"))
        lessons = course["lessons"]
    except (OSError, KeyError, json.JSONDecodeError) as error:
        print(f"Curriculum validation failed: cannot read {COURSE.name} ({error})")
        return 1

    errors: list[str] = []
    seen_lessons: set[str] = set()
    for lesson in lessons:
        lesson_id = lesson.get("id", "?")
        errors += [f"{lesson_id}: '{k}' must be non-empty text" for k in LESSON_TEXT if not text(lesson.get(k))]
        if lesson.get("level") not in LEVELS:
            errors.append(f"{lesson_id}: level must be one of {sorted(LEVELS)}")
        if not lesson.get("examples"):
            errors.append(f"{lesson_id}: examples must be a non-empty list")
        if not lesson.get("exercises"):
            errors.append(f"{lesson_id}: needs at least one exercise")
        if lesson.get("exam") not in (None, "goethe", "testdaf"):
            errors.append(f"{lesson_id}: exam must be goethe or testdaf")
        for goal in lesson.get("goals", []):
            if goal not in GOALS:
                errors.append(f"{lesson_id}: unknown goal '{goal}'")
        for required in lesson.get("requires", []):
            if required not in seen_lessons:
                errors.append(f"{lesson_id}: requires '{required}', which is not an earlier lesson")
        for word in lesson.get("vocabulary", []):
            if not (text(word.get("de")) and text(word.get("en"))):
                errors.append(f"{lesson_id}: every vocabulary item needs 'de' and 'en'")
            if word.get("article") not in (None, "der", "die", "das"):
                errors.append(f"{lesson_id}: bad article for '{word.get('de')}'")
        for exercise in lesson.get("exercises", []):
            errors += check_exercise(lesson_id, exercise)
        seen_lessons.add(lesson_id)

    for dialogue in course.get("dialogues", []):
        did = dialogue.get("id", "?")
        turns = dialogue.get("turns", [])
        if not any("options" in t for t in turns):
            errors.append(f"dialogue {did}: needs at least one learner turn")
        for turn in turns:
            if "options" in turn:
                if turn.get("answer") not in turn["options"]:
                    errors.append(f"dialogue {did}: a learner answer must be one of its options")
                if not text(turn.get("intent")):
                    errors.append(f"dialogue {did}: a learner turn needs an intent")
            elif not text(turn.get("text")):
                errors.append(f"dialogue {did}: a partner turn needs text")

    lesson_ids = Counter(lesson.get("id") for lesson in lessons)
    exercise_ids = Counter(e.get("id") for l in lessons for e in l.get("exercises", []))
    words = Counter((w.get("article", "") + " " + w.get("de", "")).strip().lower()
                    for l in lessons for w in l.get("vocabulary", []))
    for kind, counter in (("lesson", lesson_ids), ("exercise", exercise_ids), ("vocabulary item", words)):
        errors += [f"duplicate {kind} '{key}'" for key, n in counter.items() if n > 1]

    if errors:
        print("Curriculum validation failed:")
        print("\n".join(f"- {message}" for message in errors))
        return 1
    print(
        f"Curriculum valid: {len(lessons)} lessons, {sum(exercise_ids.values())} exercises, "
        f"{sum(words.values())} words, {len(course.get('dialogues', []))} dialogues."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
