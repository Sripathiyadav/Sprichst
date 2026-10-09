# Architecture decisions

## Current running MVP

```text
Flutter Views → Riverpod AppController (view-model) → Repository → local device store
```

The app keeps the same repository boundary for local and Firestore-backed learning data. The authenticated application selects `FirestoreLearningRepository`, which keeps a per-account on-device copy (`SyncedProfileStore`, `lib/data/profile_sync.dart`) so the profile loads and saves offline: the cloud is the source of truth, unsynced local changes win on the next load, and a rejected write is an error rather than a silent pending change. `LocalLearningRepository` serves the canonical `curriculum/course.json` lessons and dialogues (and the no-Firebase preview).

The app shell is responsive: phones use compact navigation, tablets use a navigation rail, and desktop gains an expanded rail. Appearance and account preferences live on `LearningProfile`, so they can be restored alongside the learning state.

## Learning engine

Pure Dart under `lib/domain`, with no UI, Firebase, or AI dependency:

| Piece | Responsibility |
| --- | --- |
| `Curriculum` | Indexes lessons once: units, per-level progress, first incomplete lesson, and exercises per skill (all O(1) or linear in the result). |
| `ExerciseEvaluator` | Deterministic grading per exercise type. Whitespace and trailing punctuation are ignored; case and umlauts are not. |
| `ExerciseSession` | Submit → feedback → advance flow shared by lessons and practice. |
| `ProgressTracker` | Turns results into lesson progress, skill stats, weak skills, mistake reviews, XP (first completion only), and streaks. |
| `ReviewScheduler` | Spaced intervals that grow with each successful recall. |

Exercises carry stable skill ids (e.g. `definite_articles`); never rename an id once learners have data. Weak skills (at least two attempts, smoothed accuracy below 75%) and recent mistakes are the only learning signals added to the AI context. `ProfileCodec` is the single place where the stored schema, defaults, and migrations live, shared by the local and Firestore repositories. Firestore writes overwrite the profile document rather than merging, because Firestore merges nested maps and would otherwise resurrect progress removed by a reset.

### Colour and surfaces

`SprichstPalette` (HCT tonal palettes, `color_system.dart`) produces both `ColorScheme`s; `toneOn` derives a foreground tone that meets a requested contrast ratio against a background tone. `GlassTheme` (a `ThemeExtension`) turns the learner's saved style and 0–100 intensity into blur, opacity, specular, shadow, and ambient-light values; read it anywhere with `context.glass`, which also honours High Contrast as "reduce transparency". `GlassSurface` is the one primitive: a plain card in standard mode, Liquid Glass otherwise, and `SoftCard`, the navigation, and the settings groups are built on it. Pages sit on `GlassPage`, which paints the ambient backdrop opaquely so route transitions never show the page behind.

### Adaptive planning

`LearningPath` chooses the next lesson (unfinished lessons at the learner's level first; a finished-but-shaky level is revisited before moving on) and decides promotion (every lesson at the level done, average best accuracy at least 70%). `AdaptivePlanner` builds practice sessions from started lessons only, scoring each exercise on due reviews, skill weakness, exercise history, novelty, and how recently it was seen, plus a difficulty fit (target 1–3 per skill from accuracy); selection is greedy with a skill-repeat penalty and runs in O(limit × candidates). Sessions retry each missed exercise once, and retries never count toward statistics. `TutorContextBuilder` sends weak skills, recent mistakes, and vocabulary from completed lessons to the gateway.

### Personalisation, exams, flashcards and games

All of this is pure Dart under `lib/domain` and covered by tests.

| Piece | Responsibility |
| --- | --- |
| `LearningGoal` + `LearningPath.choose` | Scores each lesson by goal, exam family, topics, weak skills and curriculum order (a logarithmic order prior keeps the course coherent); prerequisites (`requires`) always hold. Returns the lesson and the reasons shown to the learner. |
| `LearnerInsights` | Compares recognition (choosing) with production (typing/building) accuracy and finds the weakest and strongest answer mode from `kindStats`. This replaces "learning styles". |
| `WritingAssessor`, `SpeechMatcher` | Deterministic, explainable scoring of Schreiben (content points, structure, register, length; pass at 60%) and Sprechen (umlaut-folding edit distance; pass at 80%). The AI tutor can add feedback but never decides the grade. |
| `ExamReadiness`, `MockExam`, `ExamReport` | Per-module readiness from practice, a short Modelltest drawn from exam-style tasks, and a per-module report. Goethe is passed module by module at 60%; TestDaF levels (TDN) are only a guide. |
| `FlashcardScheduler`, `FlashcardDeck` | SM-2 variant with ease and lapses; due cards first, then a daily allowance of new words scaled to the study goal. |
| `games/` | Pure state machines (`ArticleSwipeGame`, `MemoryMatchGame`, `WordScrambleGame`, `WortleGame`, `DialogueGame`), a shared `ComboMeter`, and `WordPool` (the learner's own words first, topped up from a core list). Game answers feed the same skill statistics but never create review items. |
| `Achievements` | Daily quests (deterministic per calendar day) and badges as pure predicates over the profile, so they cannot drift from real progress. |

UI for these lives under `lib/features/{flashcards,games,gamification,practice}`. Every game offers a non-gesture, non-timer-critical path (buttons for swiping, a text field for Wortle when a screen reader is on) and does not rely on colour alone.

Adding an exercise type: extend `ExerciseKind`, add an input widget in `exercise_widgets.dart`, and handle it in `ExerciseRenderer`. The evaluator needs a change only if the type is not graded by comparison with accepted answers.

## Production learning path

```text
Flutter Views → ViewModels → Repositories → Firebase / local cache
                               ↘ AI Repository → authenticated AI gateway → Ollama
```

- Views do not talk to Firestore or Ollama.
- The learning engine owns curriculum, progress, error history, and deterministic review scheduling.
- AI receives only a selected, compact learning context and returns structured JSON.
- The personal-assistant domain is intentionally absent from this MVP.

## Data ownership

| Data | Canonical location |
| --- | --- |
| Curriculum | Git (`curriculum/course.json`, bundled as an asset and validated on load); later a read-only Firestore publish copy |
| Learning progress and review queue | Firestore `users/{uid}/...` |
| Account, appearance, learning, AI/voice, and reminder preferences | Firestore learning profile |
| Offline performance cache | local device store |
| Model weights | Ollama model store |
| AI logs/evaluation data | controlled server storage, never raw analytics |

## Firebase design

The included rules grant each signed-in person access only to their own `users/{uid}/...` documents. Curriculum, grammar, and vocabulary are authenticated-read-only. Publishing content must happen through a controlled admin/CI process, not the learner application.

## AI safety contract

The gateway holds the model connection. It keeps request sizes bounded, asks the model for JSON, and sends the learner level plus selected course context. It does not expose an Ollama port to the app. Before a public release, add Firebase ID-token verification, a per-user rate limit, structured-response validation, logging with privacy controls, and a fixed evaluation set.

Provider and voice settings are stored as account preferences only. They do not yet extend the learning-context payload or override gateway routing, which keeps optional preferences from becoming additional cloud AI data without an explicit product decision.
