# Architecture decisions

## Current running MVP

```text
Flutter Views → Riverpod AppController (view-model) → Repository → local device store
```

The app keeps the same repository boundary for local and Firestore-backed learning data. The authenticated application currently selects `FirestoreLearningRepository`; `LocalLearningRepository` remains the compatible local implementation for lessons and local-first evolution.

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
