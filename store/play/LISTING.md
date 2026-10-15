# Google Play: what to enter, and the files to upload

Everything below is ready to paste into Play Console. Files are in this folder.

## Files

| What | File | Spec |
| --- | --- | --- |
| App bundle (signed with your upload key) | `release/sprichst-1.0.0+2.aab` (git-ignored, 169 MB, arm64) | version 1.0.0, code 2 |
| App icon | `icon-512.png` | 512 × 512 PNG |
| Feature graphic | `feature-graphic-1024x500.png` | 1024 × 500 PNG |
| Phone screenshots (9) | `phone/01-…09-*.png` | 1080 × 1920 (9:16), Play wants 2–8 → upload the first 8 |
| Upload key | `~/sprichst-keys/upload-keystore.jks` + `key.properties` | **back these up** (see the end) |

Screenshot order: 01 home · 02 next lesson · 03 exercise · 04 learn · 05 practice · 06 coach with translation · 07 progress · 08 home dark · 09 learn dark.
Regenerate them with `flutter test tool/playstore_shots_test.dart`.
A 7" and 10" tablet set is optional; phone screenshots are enough to publish.

## Store listing (English, default language)

* **App name** (max 30): `Sprichst: Learn German`
* **Short description** (max 80): `Learn German by speaking it: short lessons, flashcards and a private AI tutor.`
* **Full description** (max 4000):

```
Sprichst helps you learn German by actually using it.

SHORT LESSONS, A CLEAR PATH
48 lessons from your very first words (Pre-A1) to B2, with a plan that follows
your level and your goal: everyday life, travel, work, the Goethe-Zertifikat or
TestDaF. Every answer is explained, and the next lesson is chosen for you.

A TUTOR THAT RUNS ON YOUR PHONE
Download a language model once and the coach works with no internet: write or
speak German, get corrections with the reason why, and see an English
translation of every question so you learn new words as you go. Nothing you say
leaves your phone. Prefer a cloud model? Add your own key from Groq, Google
Gemini, OpenAI, Anthropic Claude, xAI, Mistral, DeepSeek or OpenRouter, and you
choose when to use it.

PRACTISE EVERY WAY
• Daily quests and a streak that keeps you coming back
• Spaced-repetition flashcards for words you have learned
• Five quick games: articles, memory, word scramble, Wortle and conversation
• Writing practice with an on-screen ä ö ü ß keyboard, so you learn to type German fast
• A translator for German ↔ English text you type or paste
• Mock exam practice for Goethe and TestDaF goals

PRIVATE BY DESIGN
No ads. No analytics. No tracking. No Sprichst server sees your messages. Your
progress syncs through your Google account so you can switch phones, and you can
export or delete everything in the app.

Voice features use your microphone only while you record or while voice mode is on.

Sprichst is free. Language models are large (about 0.5 to 2.5 GB) and download
once over Wi-Fi when you choose; you can also use the app without them.

Questions or feedback: sripathiyadav66@gmail.com
```

* **App category**: Education · **Tags**: Language learning, Education
* **Contact email**: sripathiyadav66@gmail.com
* **Website**: https://sprichstweb.web.app
* **Phone**: optional (+49 155 65800258 is in the Impressum; leave blank if you prefer)
* **Privacy policy URL**: https://sprichstweb.web.app/legal/privacy-policy
* **Release notes (first release)**: `First release: 48 lessons, daily quests, flashcards, five games, writing practice, a translator and an AI tutor that works offline once downloaded.`

## App content (Policy → App content)

| Question | Answer |
| --- | --- |
| Privacy policy | the URL above |
| Ads | **No ads** |
| App access | **Some functionality is restricted.** Sign-in is Google only. Create a Google test account (for example a throwaway Gmail), and enter its email and password with the instructions "Tap Continue with Google, choose this account." Do not use your own account. |
| Target audience | **16–17 and 18+** only (the privacy policy says 16+). Not designed for children; not in the Families programme |
| Content rating (IARC) | Category: Reference / Education. Violence, sexual content, language, controlled substances, gambling: **No** to all. Users can interact: **No** (no chat with other people). Shares location: **No**. AI-generated content: the in-app AI tutor produces text; answer the AI questions truthfully (yes, generative AI, no user-to-user sharing). Expected rating: **Everyone / PEGI 3** |
| Government app, Financial features, Health, News, COVID-19 | **No** to all |
| Advertising ID | **No** (the app does not use it; there is no AD_ID permission in the bundle) |
| Data deletion | Account deletion URL: https://sprichstweb.web.app/legal/your-rights . In the app: Account → Danger zone → Delete account (deletes the account and learning data) |
| AI-generated content policy | The coach/translator output is AI-generated. The in-app **Account → Contact developer** lets users report bad answers; the AI transparency page explains it: https://sprichstweb.web.app/legal/ai-transparency |

### Data safety form

Collected, not shared, encrypted in transit, deletable on request:

| Data type | Collected | Why | Optional |
| --- | --- | --- | --- |
| Name, Email address, User ID (Personal info) | Yes, from Google sign-in | Account management, app functionality | No |
| App activity: in-app interactions (lessons done, scores, streak, settings) | Yes | App functionality (sync between devices) | No |

Declare **not collected**: location, contacts, photos, files, financial info, health, web browsing, device or other IDs, crash logs, diagnostics, audio (voice is turned into text on the phone and the audio is thrown away), and chat messages (the coach text stays on the phone, or goes straight from the phone to the AI provider the learner chose with their own key; Sprichst never receives it).

* **Shared with third parties**: none. (Google Firebase acts as our processor; processors are not "sharing". The learner's own AI provider is a user-initiated choice.)
* **Data processed ephemerally**: not applicable.
* **Security practices**: data is encrypted in transit: yes. Users can request data deletion: yes. Follows the Families policy: no. Independent security review: no.

### Permissions to justify

| Permission | Why |
| --- | --- |
| `RECORD_AUDIO` | Speaking practice and voice mode with the tutor; only while the learner records or voice mode is on |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Sign-in, sync, optional model downloads, optional own-key AI |
| `MODIFY_AUDIO_SETTINGS` | Plays the tutor's voice and records cleanly |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | Added by the secure-storage library for protecting the learner's own AI key; the app never asks for a fingerprint |

## Before you press "Send for review"

1. **Developer account**: one-time US$25 at play.google.com/console. A personal account created after Nov 2023 must run a **closed test with at least 12 testers for 14 days** before production. Ask friends to opt in, then apply for production access.
2. **Create the app** in Play Console: name `Sprichst: Learn German`, default language English (UK or US), App, Free.
3. **Play App Signing** (accept the default). Upload `release/sprichst-1.0.0+2.aab` to *Closed testing* first.
4. **Register Play's signing certificate for Google sign-in**: Play Console → Release → Setup → App signing → copy the *App signing key certificate* SHA-1 and SHA-256, then run
   `firebase apps:android:sha:create 1:54358857337:android:a96e9ca0987797c29f66a8 <SHA1> --project sprichst-74bed` (and again for the SHA-256), and download a fresh `google-services.json` with `firebase apps:sdkconfig ANDROID 1:54358857337:android:a96e9ca0987797c29f66a8 --project sprichst-74bed`. **Without this, Google sign-in fails for people who install from Play.**
5. **Package name `com.sprichst.app` is permanent** once published. If you would rather use a different one, change it now (see `docs/DEPLOYMENT.md`).
6. Fill *Store listing*, *App content* and the *Data safety* form from the tables above, add the images, and submit.
7. **Bump the version** for every upload: `version: 1.0.0+2` in `pubspec.yaml` (the number after `+` must go up each time).
8. Rebuild a bundle: `flutter build appbundle --release --target-platform android-arm64` (arm64 only keeps it at about 170 MB; Play's limit is 200 MB. A bundle with an Intel x86 copy is 292 MB and is rejected).

## Back up your upload key

`~/sprichst-keys/upload-keystore.jks` and `~/sprichst-keys/key.properties` (alias `upload`) are the only copy. Copy them to a password manager or an encrypted drive. If you lose them you can still ask Google to reset the upload key (Play Console → App signing), but it takes days. `android/key.properties` in the project is a copy of that file and is git-ignored.

## Still open (not needed for Android)

* iOS and macOS now use `com.sprichst.app` too (new Firebase iOS app, new `GoogleService-Info.plist`, URL scheme and keychain group updated). For the App Store you still need an Apple Developer account and signing.
* DMCA designated agent: not registered (the takedown page says so). Optional.
