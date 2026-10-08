# Sprichst

Sprichst is a Flutter German-learning MVP built around a curriculum and learning engine—not a generic chatbot. It includes a polished local-first learning flow today and clean boundaries for Firebase sync and a private Ollama-backed AI tutor next.

## What is already working

- Responsive Flutter interface for mobile and desktop
- Responsive app shell: bottom navigation on phones, navigation rail on tablets, and an expanded desktop rail
- Light, dark, and system appearance modes, saved with the learner profile
- Central Account area for profile, learning preferences, AI/voice preferences, reminder preferences, privacy, support, and licenses
- Onboarding (explanation language + starting CEFR level)
- Home, roadmap (units, per-lesson status, real level progress), lesson runner, XP, progress matrix, and AI Coach screens
- Adaptive learning: a deterministic planner picks the next review, weak-skill practice, or lesson from your own answers; practice is limited to lessons you have started, difficulty follows your accuracy per skill, missed exercises are retried and respaced, and finishing a level well moves you up
- Personalised curriculum: choose a goal (everyday, travel, work, Goethe-Zertifikat or TestDaF) and the path, vocabulary and practice follow it, with the reason for each recommendation shown on the roadmap
- Exam-style tasks modelled on the Goethe-Zertifikat and TestDaF modules: reading over a passage, listening (read aloud by the tutor, transcript always available), Lückentext, writing against content points (Leitpunkte) with a live checklist, speaking (record, transcribe, compare), a graph description task, and a mock exam (Modelltest) with a per-module report
- Flashcards with spaced repetition (a deterministic SM-2 variant): nouns are shown without their article so the article is recalled too, and a card flips to meaning → German once it is well known
- Five games: Artikel-Rausch (swipe der/die/das), Memory, Buchstabensalat (word scramble), Wortle (five-letter German word), and Gespräch (conversation fill-ups), with combos, stars, daily quests and badges
- Insights drawn from how you answer (recognition vs. recall, weakest and strongest mode). Sprichst deliberately does not use "learning styles" such as VARK, which research has not supported; see `docs/learning-design.md`
- Learning engine: eight exercise types with deterministic evaluation, per-skill accuracy, weak-skill tracking, mistake reviews, and targeted practice
- 25 lessons from Pre-A1 to B2 in `curriculum/course.json`, with 150 vocabulary words, 7 dialogues, and Goethe A1–B1 and TestDaF task lessons
- Deterministic spaced repetition for reviews and flashcards (Again → 10 minutes; successful recalls grow the gap)
- On-device persistence through `shared_preferences`, so progress survives an app restart
- Separate reset-learning-progress and reauthenticated delete-account flows
- FastAPI AI gateway with `/health`, `/v1/correct`, `/v1/chat`, `/v1/explain`, and `/v1/practice`
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

The app runs immediately in local-first demo mode. It deliberately does not require a Firebase project or an LLM to launch.

## Run the AI gateway (optional)

```bash
ollama pull qwen2.5:0.5b-instruct
ollama serve
cd ai-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Check `http://127.0.0.1:8000/health`. Before connecting a mobile device or exposing the service, read [docs/SETUP.md](docs/SETUP.md): the gateway must remain behind authentication and HTTPS.

## Preview the app without signing in

`tool/preview_main.dart` runs the real app with a fake signed-in learner and seeded progress, so you can inspect every screen (and light/dark mode) without Google sign-in or Firebase:

```bash
flutter run -t tool/preview_main.dart
# or preview a look:
flutter run -t tool/preview_main.dart \
  --dart-define=PREVIEW_APPEARANCE=dark --dart-define=PREVIEW_STYLE=glass --dart-define=PREVIEW_INTENSITY=80
```

## Design

**Colour.** The brand is the German flag: black `#000000`, red `#DD0000`, gold `#FFCE00`. The palette is built from colour theory in HCT (hue, chroma, tone) in `lib/app/theme/color_system.dart`: neutrals are tinted with the gold hue so greys feel warm, foreground tones are derived from their background to hit WCAG contrast instead of being hand-picked, and roughly 60% of a screen is neutral surface, 30% ink and containers, 10% accent. Light mode is white with a black primary action and red accent; dark mode is flag-black with a gold primary action. Gold marks correct answers and achievements, red marks mistakes, and every state also carries an icon and a word. Tests enforce AA contrast, tone derivation, brand fidelity, and colour-blind safety (protan, deutan, tritan simulation).

**Liquid Glass.** Under Account → Appearance, choose **Standard** (flat, opaque) or **Liquid Glass**, and set the glass **intensity** from subtle to strong with a live preview. Intensity drives blur, fill opacity, the light-catching edge, shadow, and the red/gold light behind the glass. Blur is used only on the floating navigation (content scrolls beneath it); cards are frosted but unblurred, which keeps scrolling smooth. Fill opacity never drops below a floor that a test proves keeps text at 4.5:1 over the worst backdrops at every intensity. Devices set to High Contrast get opaque surfaces whatever is chosen.

**Apple Human Interface Guidelines.** The Apple type scale with Dynamic Type, continuous ("squircle") corners, capsule buttons, inset grouped settings lists, native Cupertino alerts on Apple platforms, press-scale and haptic feedback, a floating tab bar, swipe-back navigation, and 44pt+ targets.

**Universal design.** Palette contrast, tap-target size, semantic labels, 200% text size, reduced motion, keyboard submit, and light/dark/Standard/Glass rendering are all enforced by tests.

## Important implementation boundary

Firebase/Google sign-in is intentionally not silently enabled in this ZIP because it needs your Firebase project identifiers, platform bundle IDs, Google OAuth consent configuration, and the generated `firebase_options.dart` file. The complete click-by-click finishing guide is in [docs/SETUP.md](docs/SETUP.md).

Course content belongs in `curriculum/course.json`; user progress belongs under `users/{uid}/...`; an LLM never controls review dates or has unrestricted database access.

## Account and privacy controls

Account preferences are stored with the learner profile. The AI and voice controls are safe account preferences: the gateway continues to own provider credentials, model access, and live routing. The privacy screen describes the current data paths without implying that a preference changes gateway behavior before that support is implemented.

Reset learning progress removes completed lessons, reviews, XP, and streaks while retaining the account and preferences. Delete account asks the user to reauthenticate, removes the current Firestore learning documents, then deletes the Firebase Authentication account.
