# Sprichst documentation

Sprichst teaches German by speaking it: short lessons from Pre-A1 to B2, daily
quests, flashcards, five mini-games, writing practice, a translator and an AI
tutor that runs on the phone or with the learner's own AI key.

This page is the map. Each topic has one detailed document below.

| Read this | When you want to |
| --- | --- |
| [Setup](SETUP.md) | Run the app on your machine, including Firebase and the optional dev server |
| [Architecture](architecture.md) | Understand the main design decisions and why they were made |
| [On-device AI](on-device-ai.md) | Know how the offline tutor, speech and voices work |
| [Zero-cost architecture](zero-cost-architecture.md) | See what runs for free, and why there is no Sprichst AI server |
| [Voice](voice.md) | Work on speech recognition, the tutor's voice and speaking practice |
| [Learning design](learning-design.md) | Understand how lessons, reviews and quests are chosen |
| [Deployment](DEPLOYMENT.md) | Ship the web app, Android and iOS, and manage the launch |

Legal documents (privacy policy, terms, Impressum and the rest) live in
[`legal/`](../legal/README.md). The public copies are at
`https://sprichst.app/legal/`.

---

## 1. What the app does

A learner signs in with Google, takes a short placement, and gets a plan:

- **Learn:** a 48-lesson course (about 260 exercises). Each lesson has an
  introduction, examples and exercises. Mistakes come back later as reviews.
- **Home:** level gauge, streak, today's three quests (lesson, flashcards,
  games; a fourth, "answer 15 correctly", appears on other days), and one
  recommended next step.
- **Practice:** flashcards with spaced repetition, five games, writing practice
  (type a German sentence, with ä ö ü ß keys), and a mock exam for Goethe and
  TestDaF goals.
- **Coach:** a German conversation partner. It corrects the learner's sentence,
  explains why, asks one follow-up question and shows an English translation of
  it. Text and voice.
- **Translator:** German to English and English to German, for text the learner
  types or pastes.
- **Progress:** XP, levels, badges and what the learner has mastered.
- **Account:** profile, goal, daily minutes, AI provider, on-device models,
  voices, privacy controls, data export and deletion.

Lessons explain in English only. Other languages are planned; the app does not
offer an explanation-language choice yet.

## 2. How it is put together

```
lib/
  app/          startup, routing, theme, the app controller (state for the whole app)
  domain/       pure Dart rules: learning path, planner, quests, flashcards, games, scoring
  data/         repositories: Firestore sync, local storage, AI providers, on-device runtime
  features/     screens, one folder per area (home, learn, practice, coach, translator, ...)
  shared/       widgets, input rules, haptics
  core/         services shared across features
curriculum/     course.json: lessons, exercises, vocabulary, dialogues
legal/          legal source documents (Markdown)
ai-server/      optional FastAPI server for development only
firebase/       Firestore rules and indexes, Storage rules, hosting config
scripts/        build, deploy, checks and generators
tool/           preview app, screenshot tools, Lottie generator
test/           Flutter tests (about 590)
store/play/     Play Store listing, images and the release checklist
```

### Layers

- **Domain** holds the rules and has no Flutter or network code. Examples are
  `learning_path.dart` (which lesson is next), `adaptive_planner.dart` (what to
  do today), `achievements.dart` (quests and badges) and
  `flashcard_scheduler.dart`. These are tested directly.
- **Data** implements the interfaces the domain declares. Examples are
  `FirestoreLearningRepository`, the local repository, `HybridAIRepository` (picks
  the on-device or cloud route) and the cloud AI providers.
- **App controller** (`lib/app/app_controller.dart`) holds the current profile and
  applies every learning event: a lesson, a practice round, flashcards, a game.
  Each event updates progress, quests and badges, then saves. Screens never write
  progress themselves.
- **Features** only read the controller and call its actions.

### Data

- **Profile:** one document per learner in Firestore, encoded by
  `lib/data/profile_codec.dart`. It holds the level, goal, lesson progress,
  skill statistics, review items, flashcard schedule, quest progress and badges.
- **Local copy:** the app keeps a copy on the device so it works offline, and
  syncs when it can (`profile_sync.dart`).
- **Secrets:** AI keys are stored only in the device's secure storage
  (`flutter_secure_storage`). They are never synced, logged or written to the
  profile.
- **Security rules:** `firebase/firestore.rules` lets each signed-in learner read
  and write only their own profile. Run the rule tests in `firebase/tests`.

### AI routing

Three ways to get a tutor reply:

1. **On-device (default when the learner downloads a model):** llama.cpp runs a
   GGUF model (Qwen 2.5 or Gemma 3). Speech uses Whisper and voices use Piper,
   both through sherpa-onnx. Nothing leaves the phone. See
   [on-device-ai.md](on-device-ai.md).
2. **Learner's own key:** the request goes straight from the phone to the
   provider the learner chose: Groq (the default model is `qwen/qwen3.8-27b`),
   Google Gemini, OpenAI, Anthropic, xAI, Mistral, DeepSeek, OpenRouter, or a
   custom HTTPS endpoint.
3. **Dev server (`ai-server/`):** only for development. It is not in the shipped
   app's path.

The learner picks the route in Account → AI & voice. The app never switches
silently: if the chosen route is unavailable it says so and does not send the
text anywhere else. In a web browser there are no local models, so the learner
must add a key.

### Quests and progress

- Each day has three quests from a rotation of four. Each quest counts something
  the learner did: finish a lesson, review flashcards (5 cards, or every card
  available that day), play two games, or answer 15 correctly.
- Quests reset at the local day boundary.
- The learning path never offers a lesson whose prerequisites are unmet, and it
  moves a learner up a level only after their level's lessons average 70%.

## 3. Tests and checks

| Check | Command |
| --- | --- |
| Static analysis | `flutter analyze` |
| App tests | `flutter test` |
| Dev server tests | `cd ai-server && .venv/bin/python -m pytest -q` |
| Course content | `python3 scripts/validate_curriculum.py` |
| Legal fields filled | `python3 scripts/check_legal_placeholders.py --strict` |
| Public legal pages current | `python3 scripts/build_legal_pages.py --check` |
| Third-party notices current | `python3 scripts/generate_third_party_notices.py --check` |

Privacy and security have their own tests. `test/privacy_audit_test.dart` checks
that no analytics or tracking code is present, and that the web app loads nothing
from Google's CDNs. `test/security_audit_test.dart` fails if a real-looking API
key is committed.

CI (`.github/workflows/ci.yml`) runs the checks above, a web build and an Android
release build on every push. Firebase's real config files are git-ignored, so CI
uses `scripts/ci_firebase_stub.py` to write placeholders.

## 4. Build and release

- **Web:** `scripts/deploy_web.sh qa 1d` for a private preview link, or
  `scripts/deploy_web.sh live` for the real site (Firebase Hosting, HTTPS).
- **Android:** `flutter build appbundle --release --target-platform android-arm64`.
  Raise `version` in `pubspec.yaml` before each upload. The Play steps are in
  [`store/play/LISTING.md`](../store/play/LISTING.md).
- **iOS and macOS:** not yet released. Needs an Apple Developer account and a
  signed build. See [DEPLOYMENT.md](DEPLOYMENT.md).

Identifiers in use:

| Item | Value |
| --- | --- |
| Android and iOS package id | `com.sprichst.app` |
| Firebase project | `sprichst-74bed` |
| Web app (main address) | `https://sprichst.app` |
| Other domains (registered, pointing at the same site) | `https://sprichst.de`, `https://sprichst.eu` |
| Firebase default address | `https://sprichst-74bed.web.app` |
| Launch site | `https://sprichstweb.web.app` |

## 5. Contributing

1. Work on a branch, or on `main` for small fixes if that's the team's habit.
2. Run `flutter analyze` and `flutter test` before pushing.
3. Add a test for each behaviour you change. The quest, course-walk and
   privacy tests are good examples to follow.
4. Keep learner data out of logs and out of the profile's secrets. Never commit
   keys, `key.properties`, keystores or the real Firebase config.
5. Legal text changes go in `legal/`, then run `scripts/build_legal_pages.py`
   and commit the generated pages.

## 6. Open items

- iOS and macOS release (Apple Developer account, signing, App Store listing).
- Google sign-in on the Play-installed Android build, after the new bundle is
  uploaded.
- Non-German explanation languages.
- Some default model ids for the non-Groq providers are unverified until tested
  with real keys.
- A professional review of the legal terms.
