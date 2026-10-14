# Deployment and management plan

Where Sprichst stands on 11 October 2026, what to do to ship it, and how to run
it afterwards without spending money you do not have to.

## 1. Test results (this branch)

| Check | Result |
| --- | --- |
| `flutter analyze` | no issues |
| `flutter test` | all 540+ tests pass |
| Course content (`scripts/validate_curriculum.py`) | valid: 48 lessons, 261 exercises |
| Third-party notices (`--check`) | current, no unknown licences |
| **Web**, release build | builds; the sign-in screen loads in a browser with no console errors |
| **Android**, debug and release | both build; runs on the API 35 emulator; Google sign-in is configured (see 3.2) |
| **iOS**, simulator | builds and runs; sign-in works after the keychain entitlement fix |
| **iOS**, release without signing | builds |
| **macOS**, debug | builds and starts, but only with a locally signed build (see 3.4) |

What could not be tested without real accounts: a full Google sign-in on the
Android emulator (it has no Google account), anything behind sign-in on web and
macOS, push-style notifications, and the microphone on a physical device.

### Findings and fixes made in this pass

* Android release builds were signed with the debug key and nothing said so. They
  now read `android/key.properties` (git-ignored) and fall back to debug only when
  it is missing.
* A CI workflow (`.github/workflows/ci.yml`) now runs analyze, tests, the notices
  and course checks, a web build and an Android release build on every pull
  request.
* Earlier in this stack: Google sign-in on iOS (keychain entitlement) and Android
  (SHA-1 registered, `google-services.json` refreshed).

### Known limits to plan around

* **App size.** A release APK with all three CPU types is about 360 MB because the
  on-device speech and language runtimes are native libraries. Ship an **app
  bundle** (`flutter build appbundle`): Google Play delivers one CPU type, about a
  third of that. The language models themselves are *not* bundled; the learner
  downloads them once.
* **macOS** needs an Apple Developer team to use Google sign-in (keychain group).
* **Web** has no on-device AI (models cannot run in a browser) and no spoken
  answers: web learners need their own AI key.

## 2. Before anything is public (blockers)

1. **Application id.** Both stores reject `com.example.*`. Pick a real id such as
   `app.sprichst.learn`, then change it in `android/app/build.gradle`
   (`namespace` and `applicationId`), Xcode (`PRODUCT_BUNDLE_IDENTIFIER` for iOS
   and macOS, and the keychain group in `Runner.entitlements`) and register the new
   apps in Firebase. Download the new `google-services.json` and
   `GoogleService-Info.plist` and update the URL scheme in `Info.plist`.
2. **Legal text.** `python3 scripts/check_legal_placeholders.py --strict` still
   lists open `[[…]]` fields (support email, supervisory authority, VAT id,
   liability clause, reviewer). Fill them, have a lawyer read the terms, and
   publish the privacy policy at a public URL (stores require one).
3. **Release signing keys.** Android upload key (`android/key.properties`), an
   Apple Developer account (paid, about US$99 a year) for iOS and macOS.
4. **Firebase.** Create the production project (or keep this one), enable Google
   sign-in, deploy rules (`firebase deploy --only firestore:rules,storage`), and
   register the *release* SHA-1 and SHA-256 for Android:
   `firebase apps:android:sha:create <appId> <sha>`. Play App Signing also has its
   own certificate: add that one too once the app is in Play Console.
5. **Quotas.** Firebase Spark is free; turn on the budget alert of the linked
   Google Cloud project at 0 so nothing can bill by accident.

## 3. Per-platform steps

### 3.1 Web (free, fastest first launch)

```bash
scripts/deploy_web.sh qa 1d   # private preview link that expires, to check first
scripts/deploy_web.sh live    # the real site
```

The script builds, then deploys (the Firebase CLI refuses a build folder outside
the config folder, so it deploys from a temporary copy of `firebase/firebase.json`).
Hosting serves everything over HTTPS with a Google-issued certificate, so the
browser shows the padlock, and compresses files with Brotli. Files the browser
never downloads (other renderers, debug symbols, the on-device speech runtime)
are left out of the upload by the `ignore` list.

`firebase/firebase.json` already sets the Content-Security-Policy, HSTS and the
other headers. Add the production domain in Firebase Auth → Authorized domains.
Check the live site with browser dev tools: no console errors, no blocked
requests other than the AI provider a tester chose.

### 3.2 Android

1. `keytool -genkey -v -keystore ~/upload.jks -keyalg RSA -keysize 2048
   -validity 10000 -alias upload`, then create `android/key.properties`.
2. `flutter build appbundle --release` and upload `build/app/outputs/bundle/
   release/app-release.aab` to an internal testing track in Play Console.
3. Fill the Data safety form from `legal/internal/records-of-processing.md`: no
   data sold or shared for ads, no analytics; account and progress data collected
   for app functionality.
4. New personal developer accounts must run a closed test with 12 testers for 14
   days before production; plan for that.

### 3.3 iOS

1. In Xcode set the team and the new bundle id; keep Keychain Sharing on.
2. `flutter build ipa --release`, upload with Transporter, test through TestFlight.
3. App Store privacy labels: same answers as the Play form. The review notes
   should explain that AI answers run on the phone or with the learner's own key.

### 3.4 macOS

Optional for launch. With a team selected in Xcode, `flutter build macos
--release` should work, and sign-in should too (not tested here: no team available). Without a team, a local build can be made by
overriding the entitlements on the command line (no keychain group), which is
fine for checking the UI but cannot sign in.

## 4. Release routine

1. Branch, change, open a PR; CI must be green (analyze, tests, builds).
2. Merge in order if PRs are stacked (they are today: #8 → #9 → #10 → this one).
3. Bump `version:` in `pubspec.yaml` (`1.0.0+1`: the part after `+` must rise on
   every store upload).
4. Tag the release, build web/AAB/IPA from the tag, ship to the test tracks first,
   promote after a day with no crashes reported.
5. Keep a `CHANGELOG` entry per release (what changed, what learners will notice).

## 5. Running it

* **Cost.** Nothing is paid per user: no AI server, no analytics, Firestore stays
  inside the free plan (profile writes are batched). Fixed costs: Google Play
  US$25 once, Apple US$99 a year, a domain if wanted. Revisit if daily Firestore
  writes approach 20k (about 300 active learners).
* **Monitoring without tracking.** The privacy policy promises no analytics, so
  do not add Crashlytics or Analytics silently. Use free signals instead: Play
  Console and App Store Connect crash reports (opt-in by the learner's device
  setting), the Firebase usage dashboard for Firestore/Auth, and the in-app
  "Contact developer" form. If you want more, add crash reporting **opt-in** and
  update the privacy policy, the data inventory and the store forms first.
* **Security hygiene.** Dependabot (or a monthly `flutter pub outdated`), rerun
  `scripts/generate_third_party_notices.py`, rotate the upload key only if
  leaked, review `firestore.rules` after every profile-model change.
* **Support.** One mailbox (the `[[SUPPORT_EMAIL]]` field), answer data requests
  within 30 days using `legal/internal/dsar-procedure.md`, keep
  `legal/internal/incident-response.md` where you can find it.
* **Content.** The course is one JSON file with a validator; new lessons ship in
  an app update. Keep lessons small and add examples in `German — English` form:
  they feed the writing practice as well.
* **Backups.** Firestore holds only progress. Turn on scheduled exports only if
  you ever outgrow the free plan; until then the learner's device holds a copy.

## 6. Next moves, in order

1. Fix the blockers in section 2 (application id, legal fields, signing keys).
2. Ship the **web build** to Firebase Hosting for friends-and-family testing.
3. Run an Android closed test (12 testers, 14 days) and a TestFlight round.
4. Public launch on Android and web, then iOS once review passes.
5. After launch, in this order: crash-free sessions (store dashboards), sign-in
   success, coach usage with and without a key, lesson completion and return rate
   (from learners' own feedback, not tracking).
6. Candidate improvements: award XP and a quest for writing practice, saved
   typing speed over time, a Windows build (the project already has the folder),
   more lessons at B1/B2, translations of the app's own interface.
