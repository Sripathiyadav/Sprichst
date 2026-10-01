# Architecture decisions

## Current running MVP

```text
Flutter Views → Riverpod AppController (view-model) → Repository → local device store
```

This is intentionally usable offline with no cloud account. `LocalLearningRepository` persists a compact profile on the device. It has exactly the same responsibility boundary a Firestore implementation will use later.

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
| Curriculum | Git (`curriculum/`); later a read-only Firestore publish copy |
| Learning progress and review queue | Firestore `users/{uid}/...` |
| Offline performance cache | local device store |
| Model weights | Ollama model store |
| AI logs/evaluation data | controlled server storage, never raw analytics |

## Firebase design

The included rules grant each signed-in person access only to their own `users/{uid}/...` documents. Curriculum, grammar, and vocabulary are authenticated-read-only. Publishing content must happen through a controlled admin/CI process, not the learner application.

## AI safety contract

The gateway holds the model connection. It keeps request sizes bounded, asks the model for JSON, and sends the learner level plus selected course context. It does not expose an Ollama port to the app. Before a public release, add Firebase ID-token verification, a per-user rate limit, structured-response validation, logging with privacy controls, and a fixed evaluation set.
