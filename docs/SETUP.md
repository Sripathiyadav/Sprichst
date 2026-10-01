# Finish Sprichst from your side

This ZIP starts as a working offline-first MVP. Complete the following in order to turn it into your cloud-connected personal app.

## 1. Open and run the project

Install the current stable Flutter SDK, then from the project root run:

```bash
flutter pub get
flutter run -d chrome
```

Finish the short onboarding. Complete the Greetings lesson, close the app, then reopen it: the lesson state and XP should still be there. That proves the local learning engine is working before introducing cloud variables.

## 2. Create the Firebase project

1. In the Firebase console, create a new project named `sprichst-personal`.
2. Add the platforms you plan to run: Android, iOS, Web, and macOS first. Use the bundle identifiers created in `android/app/build.gradle`, `ios/Runner.xcodeproj`, and `macos/Runner.xcodeproj` rather than making them up.
3. In **Authentication → Sign-in method**, enable Google. Add yourself as a test user while the OAuth consent screen is in testing mode.
4. Create a Firestore database in your preferred nearby region. Start in production mode—the repository already supplies strict rules.
5. Enable Firebase Storage if you will later host lesson audio.

## 3. Connect Flutter to Firebase

From the project root, install the Firebase tooling, log in, and generate the project-specific Dart configuration:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Select the Firebase project and platforms you registered. This creates `lib/firebase_options.dart`; it is intentionally not included in this ZIP because it belongs to your Firebase project.

Then add the Flutter packages:

```bash
flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage google_sign_in firebase_app_check firebase_analytics firebase_crashlytics firebase_messaging
```

Initialize Firebase in `lib/main.dart` before `runApp` using the generated options. Keep Firebase behind repository classes: create a `FirestoreLearningRepository` that implements `LearningRepository`, then select it only after auth is restored. Do not call `FirebaseFirestore.instance` inside a widget.

## 4. Deploy the supplied Firebase security rules

Install the Firebase CLI, authenticate, then initialize this project’s Firebase connection. Point Firestore and Storage at the files in `firebase/`:

```bash
npm install -g firebase-tools
firebase login
firebase init firestore storage
firebase deploy --only firestore:rules,firestore:indexes,storage
```

During `firebase init`, preserve the generated project alias and configure the CLI to use `firebase/firestore.rules`, `firebase/firestore.indexes.json`, and `firebase/storage.rules` (or copy those paths into the generated root `firebase.json`). Test with a non-owner account: it must not read or write another `users/{uid}` path.

## 5. Add Google sign-in safely

Use Firebase Authentication as the identity layer only. Its user ID should be the Firestore namespace: `users/{uid}/...`.

Google sign-in does **not** grant Calendar, Tasks, Gmail, Drive, or Keep access. Do not request those scopes while finishing the learning MVP. Each future external integration gets its own least-privilege OAuth flow, secure token storage, an explicit confirmation screen for write actions, and its own repository.

## 6. Run the local AI tutor

Install Ollama, then run:

```bash
ollama pull qwen2.5:0.5b-instruct
ollama serve
cd ai-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Open `http://127.0.0.1:8000/health`; its `ollama` value should be `available`.

For development, point an `ApiAIRepository` at `http://127.0.0.1:8000`. For an Android emulator use `10.0.2.2` instead of `127.0.0.1`; for a real phone, do not expose Ollama directly. Put the gateway behind HTTPS, verify Firebase ID tokens server-side, and use a private tunnel or a server you control.

## 7. Connect the app to the gateway

Replace `MockAIRepository` in `lib/app/app_controller.dart` with an HTTP-backed `AIRepository`. Send the learner’s level, current lesson, selected weak skills, and recent mistakes—not their whole Firestore document. Use the JSON endpoints the gateway exposes. Treat malformed model data and an unavailable model as graceful in-app errors, never as a reason to block learning.

## 8. Add content before adding more features

Create your lessons in `curriculum/pre_a1/` and `curriculum/a1/`. Run this before committing:

```bash
python3 scripts/validate_curriculum.py
```

Keep content in Git as the source of truth. When you need cloud distribution, publish a reviewed copy to the read-only course collections. Do not make the model the curriculum author of record.

## 9. Verify before personal beta

- `flutter analyze`
- `flutter test`
- `python3 scripts/validate_curriculum.py`
- Sign in with your Google test account and verify only that user can access its own Firestore path.
- Run the AI correction endpoint with the fixed benchmark sentence `Ich gehen morgen zur Arbeit.` and ensure its JSON remains valid.
- Disable Wi-Fi and confirm lessons, review, and saved progress still work; AI and cloud sync should fail softly.

## Recommended next implementation order

1. Firebase Auth + Firestore repository.
2. A complete reviewed Pre-A1 curriculum pack.
3. Lesson audio and listening exercises.
4. Gateway authentication + `ApiAIRepository`.
5. Fixed AI evaluation dataset and response-schema checks.
6. A1 content, then adaptive practice.

Keep the personal-assistant, Google Calendar, Tasks, and Keep work out of this milestone. The learning engine should be solid first.
