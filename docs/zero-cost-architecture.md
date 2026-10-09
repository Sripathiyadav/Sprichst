# Zero-cost architecture

Goal: Sprichst is free to build, free to run, and does not depend on your
computer after it is published. No Sprichst-owned server, GPU or paid API.

```
                Flutter app
        ┌──────────┼───────────┐
   This phone   Groq (the     Firebase
   (Gemma/Qwen  learner's     Auth + Firestore
    + Whisper    own key)     (free Spark plan)
    + Piper)
```

## Do I still need a cloud AI server? No.

The AI server existed so a provider key could stay secret on a machine you
control. With **bring-your-own-key**, each learner makes a free Groq account and
pastes their own key into the app, so there is no shared key to protect, no
traffic to carry and nothing to host. The app calls Groq directly
(`lib/data/ai/groq_ai_repository.dart`). The `ai-server/` folder is a
developer tool only: debug builds and anyone who types an address use it;
a released build ignores it.

Do **not** put your own Groq key into the app or a server for everyone: it
would be shared by all users, hit one account's limit within minutes, and a
key inside an app can be extracted. Each learner uses their own.

## What the learner sees

| Setting (Account → AI & voice) | What happens |
| --- | --- |
| **Automatic** (default) | Answers on the phone. If the models are not downloaded and the learner added a Groq key, Groq answers instead. |
| **Groq (my own key)** | Groq answers while the free daily allowance lasts. When it is used up, offline, or the key is rejected, the coach says so and offers **Answer on this phone**. It never switches by itself, so the learner always knows where their words go. |
| **This phone only** | Nothing leaves the device. Needs the models downloaded. |

No Groq account is required: the phone-only path is complete (chat,
corrections, speech recognition, spoken answers). Groq has no German voice, so
spoken answers always use the phone's Piper voices; speech *recognition* can
use Groq's Whisper.

## The key

`GroqSettings` (`lib/data/ai/groq_settings.dart`) keeps the key in
`flutter_secure_storage` (iOS/macOS Keychain, Android Keystore-backed storage;
the browser's protected storage on web). It is shown masked, validated
(`gsk_…`) and checked with Groq's `/models` before it is accepted, can be
removed in one tap, and is never logged, synced to Firebase or placed in the
profile (`test/groq_test.dart` pins this, and `test/security_audit_test.dart`
fails the build if a real key is committed). Anyone who can unlock a phone
could use a key stored on it; the screen says so and how to revoke the key at
console.groq.com.

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
* **Groq:** per account and per model; the app handles HTTP 429 (shows the
  wait time and offers the phone). The lighter 8B model uses the allowance more
  slowly than the 70B one; the learner can choose in the same screen.
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
   the Groq key and AI text go from the device to Groq only if the user adds a
   key.
5. Test in airplane mode with a downloaded model; test a Groq limit (use a key
   with a tiny allowance, or a wrong key) and check the "Answer on this phone"
   offer.
6. Record the how-to video: create a Groq account, create a key, paste it in
   Account → AI & voice → Save and test, choose the setting, what happens when
   the allowance ends, and the phone-only alternative.

## Not built yet (on purpose)

* A guest mode without a Google account. Sign-in is required today; guest data
  would need a defined merge into the account later. Everything else (lessons,
  offline AI) already works without internet once signed in and models are
  downloaded.
* Automatic provider switching, paid hosting, a shared key, usage accounting.
