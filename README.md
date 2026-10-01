# Sprichst

Sprichst is a Flutter German-learning MVP built around a curriculum and learning engine—not a generic chatbot. It includes a polished local-first learning flow today and clean boundaries for Firebase sync and a private Ollama-backed AI tutor next.

## What is already working

- Responsive Flutter interface for mobile and desktop
- Onboarding (explanation language + starting CEFR level)
- Home, roadmap, lesson runner, exercise feedback, XP, progress matrix, and AI Coach screens
- A0 / Pre-A1 and A1 foundation lessons
- Deterministic spaced repetition: Again → 10 minutes, Hard → 1 day, Good → 3 days, Easy → 7 days
- On-device persistence through `shared_preferences`, so progress survives an app restart
- FastAPI AI gateway with `/health`, `/v1/correct`, `/v1/chat`, `/v1/explain`, and `/v1/practice`
- Curriculum JSON and a validation script
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

Course content belongs in `curriculum/`; user progress belongs under `users/{uid}/...`; an LLM never controls review dates or has unrestricted database access.
