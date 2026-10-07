# Sprichst

Sprichst is a Flutter German-learning MVP built around a curriculum and learning engine—not a generic chatbot. It includes a polished local-first learning flow today and clean boundaries for Firebase sync and a private Ollama-backed AI tutor next.

## What is already working

- Responsive Flutter interface for mobile and desktop
- Responsive app shell: bottom navigation on phones, navigation rail on tablets, and an expanded desktop rail
- Light, dark, and system appearance modes, saved with the learner profile
- Central Account area for profile, learning preferences, AI/voice preferences, reminder preferences, privacy, support, and licenses
- Onboarding (explanation language + starting CEFR level)
- Home, roadmap (units, per-lesson status, real level progress), lesson runner, XP, progress matrix, and AI Coach screens
- Learning engine: multiple-choice, fill-in, translation, and word-order exercises with deterministic evaluation, per-skill accuracy, weak-skill tracking, mistake reviews, and targeted practice
- Nine A0 / Pre-A1 and A1 lessons in `curriculum/course.json` (greetings, introductions, numbers, articles, sein, haben, regular verbs, word order, accusative)
- Deterministic spaced repetition: Again → 10 minutes; Hard, Good, and Easy start at 1, 3, and 7 days and grow ×1.2, ×2.5, and ×3.5 with each successful recall (capped at 180 days)
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

## Important implementation boundary

Firebase/Google sign-in is intentionally not silently enabled in this ZIP because it needs your Firebase project identifiers, platform bundle IDs, Google OAuth consent configuration, and the generated `firebase_options.dart` file. The complete click-by-click finishing guide is in [docs/SETUP.md](docs/SETUP.md).

Course content belongs in `curriculum/course.json`; user progress belongs under `users/{uid}/...`; an LLM never controls review dates or has unrestricted database access.

## Account and privacy controls

Account preferences are stored with the learner profile. The AI and voice controls are safe account preferences: the gateway continues to own provider credentials, model access, and live routing. The privacy screen describes the current data paths without implying that a preference changes gateway behavior before that support is implemented.

Reset learning progress removes completed lessons, reviews, XP, and streaks while retaining the account and preferences. Delete account asks the user to reauthenticate, removes the current Firestore learning documents, then deletes the Firebase Authentication account.
