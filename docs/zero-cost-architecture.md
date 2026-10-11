# Zero-cost architecture

Goal: Sprichst is free to build, free to run, and does not depend on your
computer after it is published. No Sprichst-owned server, GPU or paid API.

```
                Flutter app
        ┌──────────┼───────────┐
   This phone   The learner's  Firebase
   (Gemma/Qwen  own AI account Auth + Firestore
    + Whisper    (Groq, Gemini, (free Spark plan)
    + Piper)     OpenAI, Claude,
                 Grok, …)
```

## Do I still need a cloud AI server? No.

The AI server existed so a provider key could stay secret on a machine you
control. With **bring-your-own-key**, each learner pastes a key from any platform they
already use (Groq, Google Gemini, OpenAI, Anthropic Claude, xAI Grok, Mistral,
DeepSeek, OpenRouter, or any server that speaks the OpenAI chat API), so there
is no shared key to protect, no traffic to carry and nothing to host. The app
calls that provider directly (`lib/data/ai/cloud_ai_repository.dart`; the
providers are listed in `lib/data/ai/cloud_providers.dart`, and adding another
is one entry). The `ai-server/` folder is a
developer tool only: debug builds and anyone who types an address use it;
a released build ignores it.

Do **not** put your own provider key into the app or a server for everyone: it
would be shared by all users, hit one account's limit within minutes, and a
key inside an app can be extracted. Each learner uses their own.

## What the learner sees

| Setting (Account → AI & voice) | What happens |
| --- | --- |
| **Automatic** (default) | Answers on the phone. If the models are not downloaded and the learner added a key, their provider answers instead. |
| **My own AI key** | The chosen provider answers while the allowance lasts. When it is used up, there is no credit, the learner is offline, or the key is rejected, the coach says so and offers **Answer on this phone**. It never switches by itself, so the learner always knows where their words go. |
| **This phone only** | Nothing leaves the device. Needs the models downloaded. |

No AI account is required: the phone-only path is complete (chat,
corrections, speech recognition, spoken answers). No provider has a German voice the app uses, so
spoken answers always use the phone's Piper voices; speech *recognition* can
use Whisper at Groq or OpenAI, and falls back to the phone for the others.

## The key

`CloudAISettings` (`lib/data/ai/cloud_ai_settings.dart`) keeps one key per provider in
`flutter_secure_storage` (iOS/macOS Keychain, Android Keystore-backed storage;
the browser's protected storage on web). It is shown masked, checked for shape
(providers change key formats, so the provider decides) and tested with the provider's `/models` before it is accepted, can be
removed in one tap, and is never logged, synced to Firebase or placed in the
profile (`test/cloud_ai_test.dart` pins this, and `test/security_audit_test.dart`
fails the build if a real key is committed). Anyone who can unlock a phone
could use a key stored on it; the screen says so and how to revoke the key in
the provider's console. A custom server address must be https, so a key never
travels in the clear.

## Free quotas to watch

* **Firestore (Spark):** 1 GiB, 50k reads, 20k writes, 20k deletes a day for the
  whole project. Mitigations in the app: the profile is one small document;
  changes are gathered for 8 seconds into a single write and pushed when the app
  goes to the background (`SyncedProfileStore`); lessons live in the app, not in
  Firestore; reads happen once at start. Roughly, 20k writes a day is a few
  hundred active learners at 50 to 100 writes each; if you outgrow it, Firestore
  rejects writes (it does not charge on Spark) and the app keeps the data on the
  device and retries.
* **Firebase Auth:** generous free tier for Google sign-in.
* **AI providers:** per account and per model. The app handles rate limits
  (HTTP 429: shows the wait time and offers the phone), no-credit answers and
  unknown model names. Free tiers exist at Groq, Gemini and OpenRouter (`:free`
  models); OpenAI, Anthropic and xAI normally need prepaid credit on the
  learner's own account. The learner can pick a lighter model in the same
  screen.
* **No Cloud Functions / Cloud Run:** not needed; avoid them on Spark.

## Costs that remain

* Google Play: a one-time developer registration fee (about US$25). New
  personal accounts also have to complete Google's testing requirements.
* Apple: App Store distribution needs the paid Developer Program; Android and
  the web cost nothing beyond the above.

## Release checklist (Android)

1. Replace the placeholder application id `com.example.sprichst` in
   `android/app/build.gradle` (Play rejects `com.example.*`) and register that
   package in Firebase; download its `google-services.json`.
2. Add your release signing key (never commit it) and build:
   `flutter build appbundle --release`.
3. minSdk is 24 (needed for the Keystore-backed storage and the models).
4. Fill `legal/` (`python3 scripts/check_legal_placeholders.py --strict`),
   publish the Privacy Policy at a URL, and answer the Data safety form from
   `legal/internal/records-of-processing.md`: account info and app activity are
   collected for app functionality; no data is sold or shared for advertising;
   the AI provider key and AI text go from the device to the provider the
   learner chose, only if the user adds a key.
5. Test in airplane mode with a downloaded model; test a provider limit (use a key
   with a tiny allowance, or a wrong key) and check the "Answer on this phone"
   offer.
6. Record the how-to video: create an account at a provider (Groq and Gemini have free tiers), create a key, paste it in
   Account → AI & voice → Save and test, choose the setting, what happens when
   the allowance ends, and the phone-only alternative.

## Not built yet (on purpose)

* A guest mode without a Google account. Sign-in is required today; guest data
  would need a defined merge into the account later. Everything else (lessons,
  offline AI) already works without internet once signed in and models are
  downloaded.
* Automatic provider switching, paid hosting, a shared key, usage accounting.
