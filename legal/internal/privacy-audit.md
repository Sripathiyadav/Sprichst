# Privacy audit (8 October 2026)

Scope: the Flutter app (web, iOS, Android, desktop) and the web host configuration. The AI path has no Sprichst server: the app calls the learner's own AI provider account directly (Groq, Gemini, OpenAI, Anthropic, xAI, Mistral, DeepSeek, OpenRouter or a custom OpenAI-compatible server; updated 11 October 2026).

## 1. Google Fonts and other Google-hosted assets

Question: does the app make visitors' browsers send their IP address to Google?

| Finding | Before | Action | Now |
|---|---|---|---|
| `google_fonts` package | Not used | none | none |
| Roboto, loaded by Flutter web from `fonts.gstatic.com` | Yes, on every page load | Roboto bundled in `assets/fonts/roboto` (Apache-2.0), declared in `pubspec.yaml` | Served from our origin |
| Flutter fallback fonts (Noto) from `fonts.gstatic.com` | Yes, when glyphs were missing | `fontFallbackBaseUrl` pointed at our own origin in `web/flutter_bootstrap.js` | No request leaves the origin |
| CanvasKit renderer from `www.gstatic.com/flutter-canvaskit` | Yes | `canvasKitBaseUrl: 'canvaskit/'` (served locally) | Served from our origin |
| Firebase JS SDK from `www.gstatic.com/firebasejs` | Yes | Vendored into `web/vendor/firebasejs` (`scripts/vendor_web_deps.py`); `window.firebase_core` set before FlutterFire loads | Served from our origin |
| Google Sign-In JS (`accounts.google.com/gsi/client`), loaded on app start by `google_sign_in_web` | Yes | `google_sign_in_web` replaced by a no-op stub via `dependency_overrides` (`tool/stubs/google_sign_in_web`); web sign-in uses Firebase's popup flow | Contacted only after the user presses "Continue with Google" |
| `<meta name="google-signin-client_id">` | Present | Removed | |
| Referrer | default | `<meta name="referrer" content="no-referrer">` and header `Referrer-Policy` | |

Verified in a real browser with the network panel: a cold page load makes zero requests to hosts other than our own.

Note on remaining Google contact: signing in or saving progress necessarily talks to Google (Firebase Authentication, Cloud Firestore, and `apis.google.com` / `<project>.firebaseapp.com` for the popup). These happen only after a user action, are disclosed in the Privacy Policy, and are covered by Google's DPA. If this is unacceptable for a market, the alternatives are email-link sign-in via your own backend, or a self-hosted identity provider.

## 2. Analytics and session replay

Dependencies searched: `pubspec.yaml`, `pubspec.lock`, `web/`, `ai-server/requirements.txt`, platform folders. No `firebase_analytics`, `firebase_crashlytics`, `firebase_performance`, `google_mobile_ads`, Sentry, Datadog, PostHog, Mixpanel, Amplitude, Segment, Hotjar, FullStory, LogRocket, Smartlook, Microsoft Clarity, Mouseflow or similar. No session replay, screen recording, heatmap or fingerprinting code. No `<script>` tags in `web/index.html` except the local Flutter bootstrap.

Enforced by `test/privacy_audit_test.dart`, which fails the build if a tracking package, a tracking host, a CDN or a Google Fonts URL is added to any tracked file. If you ever add analytics, it must be privacy-friendly, cookieless, EU-hosted, off by default until consent, and listed in the Privacy Policy and Cookies notice first.

## 3. Cookies and storage

No cookies are set by us. Firebase Authentication keeps its session in IndexedDB. See `cookies-and-storage.md`. No consent banner is required because nothing non-essential is stored.

## 4. Data minimisation

- The AI context never includes name or email.
- Voice recordings are transcribed and discarded.
- The gateway's `/health` reveals nothing about configuration.
- Server logs hold IP and request metadata only; set a retention period.

## 5. Open items for the operator

- Choose the Firestore location (EU for EU users) and record it in the Privacy Policy.
- A provider is contacted only from the learner's device with the learner's own key, only after they add one and choose to use it (or Automatic with a model missing). The provider hosts (`api.groq.com`, `generativelanguage.googleapis.com`, `api.openai.com`, `api.anthropic.com`, `api.x.ai`, `api.mistral.ai`, `api.deepseek.com`, `openrouter.ai`) are the only AI hosts in the web CSP and in `test/privacy_audit_test.dart`. A custom server address is typed by the learner, must be https, and is not available in the web build.
