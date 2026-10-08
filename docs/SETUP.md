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

### iOS Google sign-in checklist

Sign-in fails on iOS unless all three of these are in place:

1. **Download `GoogleService-Info.plist` after enabling Google sign-in** in Firebase (Authentication → Sign-in method). A plist downloaded earlier lacks `CLIENT_ID` and `REVERSED_CLIENT_ID`; re-download it and replace `ios/Runner/GoogleService-Info.plist` (git-ignored).
2. **`ios/Runner/Info.plist` carries two values from that file**: `GIDClientID` (the `CLIENT_ID`) and a `CFBundleURLTypes` entry whose scheme is the `REVERSED_CLIENT_ID`. Google redirects back into the app through that scheme. If you ever regenerate the Firebase iOS app, update both.
3. The bundle identifier in Xcode matches the one registered in Firebase (`com.example.sprichst` today).

On a simulator, iOS shows a "Wants to Use google.com to Sign In" prompt first; that is expected. If Firebase later reports `keychain-error`, enable **Keychain Sharing** for the Runner target in Xcode.

### Microphone permissions

Voice practice needs a usage string on each platform, or the OS ends the app the moment the microphone is touched: `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist` and `macos/Runner/Info.plist`, `RECORD_AUDIO` in the Android manifest, and the `com.apple.security.device.audio-input` entitlement for sandboxed macOS builds. Browsers need HTTPS or localhost.

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

The app finds the gateway by itself in development (`lib/app/ai_server_url.dart`): the iOS simulator, desktop and web use `http://127.0.0.1:8000`, and the Android emulator uses `http://10.0.2.2:8000`, its alias for your computer. Both were checked end to end (voices, chat, speech, playback, transcription).

For a real phone on the same Wi-Fi:

1. Start the gateway with `ai-server/run.sh`. It listens on your network (a plain `uvicorn ... --reload` only listens on this computer, which a phone cannot reach) and prints the address to use.
2. If macOS asks whether Python may accept incoming connections, choose Allow. If you missed it: System Settings → Network → Firewall → Options, and allow the Python that runs the server.
3. In the app, open Account → AI & voice → AI server, enter that address (for example `192.168.1.20`) and tap Save and test. The result says what is wrong if it fails. The address is remembered on that phone.

Alternatively, bake the address in at build time with `flutter run --dart-define=AI_SERVER_URL=http://<your-computer's-LAN-IP>:8000`.

iOS and debug Android builds are allowed to use plain HTTP on the local network for this (`NSAllowsLocalNetworking` in `Info.plist`; a debug-only `network_security_config.xml`). Release builds must use HTTPS. Only do this on a network you trust: the gateway has no authentication. Do not expose Ollama directly. For anything beyond your own desk, put the gateway behind HTTPS, verify Firebase ID tokens server-side, and use a private tunnel or a server you control.

Android blocks plain HTTP by default. `android/app/src/main/res/xml/network_security_config.xml` allows it only for the device's own loopback address, which `just_audio` needs to play the tutor's speech.

## 7. On-device AI and the gateway

The app already uses the gateway through `HybridAIRepository` (`lib/app/app_controller.dart`): the AI Coach runs on the phone once its models are downloaded, and uses the gateway only as the learner's setting allows. See [on-device-ai.md](on-device-ai.md) for the models, platform requirements (iOS 16.4+) and the one-time keychain prompt during the first iOS build.

## 8. Add content before adding more features

Add lessons to `curriculum/course.json`; the app bundles it as an asset and checks it when it starts. Skill ids on exercises are stable keys for weak-skill tracking, so never rename one once learners have data. Run this before committing:

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
