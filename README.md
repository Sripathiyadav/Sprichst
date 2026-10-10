# Sprichst

Sprichst is a Flutter German-learning MVP built around a curriculum and learning engine—not a generic chatbot. Learners sign in with Google; their profile lives in Firestore with an on-device copy so they can keep studying offline, and the AI tutor runs on the phone or, optionally, on the learner's own free Groq account. There is no Sprichst AI server.

## What is already working

- Responsive Flutter interface for mobile and desktop
- Responsive app shell: bottom navigation on phones, navigation rail on tablets, and an expanded desktop rail
- Light, dark, and system appearance modes, saved with the learner profile
- Central Account area for profile, learning preferences, AI/voice preferences, reminder preferences, privacy, support, and licenses
- On-device AI: the AI Coach (chat, corrections, speech recognition and voice) runs on the phone after a one-time model download, and works with no internet. The app recommends a model for the phone's memory; the learner can pick any. See [docs/on-device-ai.md](docs/on-device-ai.md)
- Onboarding (explanation language + starting CEFR level)
- Home, roadmap (units, per-lesson status, real level progress), lesson runner, XP, progress matrix, and AI Coach screens
- Adaptive learning: a deterministic planner picks the next review, weak-skill practice, or lesson from your own answers; practice is limited to lessons you have started, difficulty follows your accuracy per skill, missed exercises are retried and respaced, and finishing a level well moves you up
- Personalised curriculum: choose a goal (everyday, travel, work, Goethe-Zertifikat or TestDaF) and the path, vocabulary and practice follow it, with the reason for each recommendation shown on the roadmap
- Exam-style tasks modelled on the Goethe-Zertifikat and TestDaF modules: reading over a passage, listening (read aloud by the tutor, transcript always available), Lückentext, writing against content points (Leitpunkte) with a live checklist, speaking (record, transcribe, compare), a graph description task, and a mock exam (Modelltest) with a per-module report
- Flashcards with spaced repetition (a deterministic SM-2 variant): nouns are shown without their article so the article is recalled too, and a card flips to meaning → German once it is well known
- Five games: Artikel-Rausch (swipe der/die/das), Memory, Buchstabensalat (word scramble), Wortle (five-letter German word), and Gespräch (conversation fill-ups), with combos, stars, daily quests and badges
- Insights drawn from how you answer (recognition vs. recall, weakest and strongest mode). Sprichst deliberately does not use "learning styles" such as VARK, which research has not supported; see `docs/learning-design.md`
- Learning engine: eight exercise types with deterministic evaluation, per-skill accuracy, weak-skill tracking, mistake reviews, and targeted practice
- 48 lessons from Pre-A1 to B2 in `curriculum/course.json`, with 308 vocabulary words, 13 dialogues, Goethe A1–B2 task lessons and a four-part TestDaF track (reading, listening, written argument, speaking)
- Deterministic spaced repetition for reviews and flashcards (Again → 10 minutes; successful recalls grow the gap)
- Offline-tolerant sync: the profile is saved to Firestore and mirrored per account on the device. Changes are gathered for a few seconds into one write (to stay inside Firestore's free quota) and pushed when the app goes to the background; offline changes are kept and pushed on the next load (the policy is documented in `lib/data/profile_sync.dart`: the cloud is the source of truth, pending local changes win, last writer wins)
- Separate reset-learning-progress and reauthenticated delete-account flows
- Developer-only FastAPI gateway (`ai-server/`, not in the released app): `GET /health`, `GET /health/ready` (provider reachable?), `POST /v1/correct`, `POST /v1/chat`, `POST /v1/transcribe`, `POST /v1/speak`, `GET /v1/voices`. Model answers are validated before they reach the app, concurrent jobs are capped, and an optional fallback provider is supported
- Versioned curriculum JSON, validated by both a script and the app's parser
- Firebase Firestore and Storage security rules ready to deploy

## Project map

```text
lib/                 Flutter application (MVVM-inspired layers)
ai-server/           Private FastAPI gateway for Ollama
curriculum/          Version-controlled, canonical course content
firebase/             Firestore and Storage security configuration
scripts/              Curriculum validation
docs/                 Architecture and handoff instructions
```

## Run it locally

```bash
flutter pub get
flutter run -d chrome
```

The real app signs in with Google, so it needs your Firebase project's `lib/firebase_options.dart` (git-ignored; create it with `flutterfire configure`, see [docs/SETUP.md](docs/SETUP.md)). If Firebase cannot start, the app says so instead of showing a blank screen. To try every screen with no Firebase and no AI server, use the preview below.

## AI: the phone, or your own Groq key (no server)

Sprichst has no AI server of its own and needs none. The tutor either runs on the phone (see [docs/on-device-ai.md](docs/on-device-ai.md)) or, if the learner adds their own free [Groq](https://console.groq.com) key in Account → AI & voice, calls Groq directly from the app. When the Groq daily allowance runs out the learner is asked whether to continue on the phone; nothing switches silently. The key lives in the device's secure storage and is never synced. The full reasoning and quotas are in [docs/zero-cost-architecture.md](docs/zero-cost-architecture.md).

## Developer gateway (optional, not part of the released app)

`ai-server/` is a FastAPI gateway kept for development and experiments (for example trying Ollama models on a Mac). Debug builds, and anyone who types an address in Account → AI & voice, can use it; released builds ignore it.

```bash
ollama pull qwen2.5:0.5b-instruct
ollama serve
cd ai-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Check `http://127.0.0.1:8000/health`. To use the gateway from a real phone, start it with `./run.sh` instead and enter the address it prints in Account → AI & voice → Developer AI server.

### Voices (open-source, optional)

The tutor speaks with [Piper](https://github.com/OHF-Voice/piper1-gpl) voices that run on your own machine. Without them the gateway uses the macOS voice, so voice features still work.

```bash
cd ai-server
pip install -r requirements-voices.txt            # the Piper engine
python3 scripts/download_voices.py                # Thorsten (recommended, CC0)
python3 scripts/download_voices.py --all          # every voice in the catalogue
```

Voices are saved to `~/.sprichst/voices` (set `PIPER_VOICES_DIR` to change it). Learners pick a voice, hear a preview and set the speed under Account → AI & voice; a voice that is not installed falls back to the best one that is. See [docs/voice.md](docs/voice.md) for the catalogue, licences and how hands-free voice mode works. Before connecting a mobile device or exposing the service, read [docs/SETUP.md](docs/SETUP.md): the gateway must remain behind authentication and HTTPS.

## Preview the app without signing in

`tool/preview_main.dart` runs the real app with a fake signed-in learner and seeded progress, so you can inspect every screen (and light/dark mode) without Google sign-in or Firebase:

```bash
flutter run -t tool/preview_main.dart
# or preview a look:
flutter run -t tool/preview_main.dart \
  --dart-define=PREVIEW_APPEARANCE=dark --dart-define=PREVIEW_STYLE=glass --dart-define=PREVIEW_INTENSITY=80
```

To review the design without a device, render the main screens (light and dark, phone and wide) to PNG files: `SHOT_DIR=build/shots flutter test tool/screenshots_test.dart`.

## Design

The look is the Sprichst design system (a published design-system artifact: brand book, tokens, components). The interface borrows from a well-set e-reader: warm paper, charcoal panels, one coral shape and large, quiet numbers. Each screen has one next step, and the one number that matters is set large.

- **Tokens** are in `lib/app/theme/color_system.dart` (`SprichstTokens`, light and dark, read with `context.tokens`) and `lib/app/theme/app_theme.dart` (the type scale, spacing, radii, component themes). Dark is designed on its own: the canvas is never pure black, coral is muted a step, and the primary action turns coral. `test/theme_contrast_test.dart` holds every documented text and control pair to WCAG AA in both themes.
- **Type** is Figtree, bundled (SIL OFL) so no font is fetched from a CDN; Roboto is the fallback. Light numerals and medium headings carry the look; nothing is smaller than 13px and the system text size always applies.
- **Components** (`lib/shared/widgets/`): `Masthead`/`MastheadBar` (ink rule, wordmark row, hairline), `FeaturePanel` (the one charcoal panel per screen), `EditorialNumber` (the hero number on its coral disc), `PrimaryButton` (charcoal with a coral arrow; coral in dark), `OptionTile` (answers and choices: icon and word for correct and incorrect), `FeedbackBanner`, `StateMessage` (loading, empty, error, offline), `WeekActivity`, `LevelBadge`, `DsChip`, `Geometry` (decoration only, hidden from screen readers) and the `Wordmark`/`AppIcon` brand marks.
- **Rules the code keeps**: one primary action or one panel per screen; status never by colour alone; interface in English, German text marked as German for screen readers; no exclamation marks in interface copy; honest data only (no placeholder numbers, empty states instead of zeros); every control at least 48px; reduced motion makes durations zero and stops the loading arc.
- **Liquid Glass is retired.** It belonged to the previous look; every learner now gets the flat paper-and-panel surfaces. The old glass code remains in `lib/app/theme/glass_theme.dart` and `lib/shared/widgets/glass.dart`, switched off.
- **Icons**: the orbit mark from the design system is in `assets/brand/`; `python3 scripts/make_app_icons.py` writes the iOS (light and dark), macOS, Android (adaptive and themed), web and Windows icons from it.
- **Review the design** without a device: `SHOT_DIR=build/shots flutter test tool/screenshots_test.dart` renders the main screens in light and dark.

## Important implementation boundary

Firebase/Google sign-in is intentionally not silently enabled in this ZIP because it needs your Firebase project identifiers, platform bundle IDs, Google OAuth consent configuration, and the generated `firebase_options.dart` file. The complete click-by-click finishing guide is in [docs/SETUP.md](docs/SETUP.md).

Course content belongs in `curriculum/course.json`; user progress belongs under `users/{uid}/...`; an LLM never controls review dates or has unrestricted database access.

## Legal, privacy and security

The [legal/](legal/README.md) folder holds the Privacy Policy, Terms, Disclaimer, AI Transparency notice, Cookies and Storage notice, Your Rights, Copyright and Takedown (with the DMCA agent details), Impressum, Accessibility statement, Security summary and generated Third-Party Notices, plus internal compliance records. They are templates, not legal advice: fill the `[[PLACEHOLDER]]` fields (`python3 scripts/check_legal_placeholders.py`) and have a lawyer review them before launch. The user-facing documents are bundled and shown in the app under Account → Legal.

What the build guarantees (each is enforced by tests):

- **No third-party requests from the web app.** Fonts (Roboto), the renderer and the Firebase SDK are bundled; no Google Fonts, CDN, analytics or session replay. See `legal/internal/privacy-audit.md`.
- **No secrets in the frontend.** AI-provider keys live only in `ai-server/.env`.
- **Row-level security.** Firestore rules let a signed-in user touch only their own documents and validate every field. `cd firebase && npm install && npm test`.
- **Validated inputs** in the app and in the AI server, with rate limiting and optional Firebase sign-in checks.
- **No raw SQL.** There is no SQL database; tests fail if one is introduced.

See [SECURITY.md](SECURITY.md) to report a vulnerability.

## Account and privacy controls

Account preferences are stored with the learner profile. The AI and voice controls are preferences only: they choose where the tutor answers (this phone, or the learner's own Groq account). The Groq key is never part of the profile; it stays in the device's secure storage. The privacy screen describes the real data paths.

Reset learning progress removes completed lessons, reviews, XP, and streaks while retaining the account and preferences. Delete account asks the user to reauthenticate, removes the current Firestore learning documents, then deletes the Firebase Authentication account.
