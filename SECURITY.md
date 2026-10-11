# Security policy

## Reporting a vulnerability

Please report security problems privately to **[[SECURITY_EMAIL]]** (or through GitHub's "Report a vulnerability" on this repository). Do not open a public issue. Include what you found, how to reproduce it, and the impact. We acknowledge reports within 3 working days, aim to fix serious problems within 30 days, and will credit you if you wish. Please do not access other people's data, run denial-of-service tests, or test against production accounts beyond your own. Good-faith research within these limits will not be pursued legally.

## Design rules this project enforces with tests

| Rule | Where it is enforced |
|---|---|
| No API keys or secrets in the app or repository | `test/security_audit_test.dart` scans tracked files for key patterns; provider keys exist only in `ai-server/.env` (git-ignored) |
| Row-level security: users read and write only their own data; strict schema on every write; deny by default | `firebase/firestore.rules`, `firebase/storage.rules`; `cd firebase && npm test` runs them in the Firestore emulator, including the exact document the app writes |
| Validate inputs on both sides | `lib/shared/input_rules.dart` (client), `ai-server/app/security.py` and pydantic models (server); `test/input_validation_test.dart`, `ai-server/tests/test_security.py` |
| No raw SQL | There is no SQL database. `ai-server/tests/test_no_raw_sql.py` and `test/security_audit_test.dart` fail on SQL drivers or string-built queries |
| No tracking, analytics, session replay or third-party fonts / CDNs | `test/privacy_audit_test.dart` |
| Authenticated, rate-limited AI server | `AUTH_REQUIRED=1`, `RATE_LIMIT_PER_MINUTE`; see `docs/SETUP.md` |

## Notes for operators

- The Firebase web/mobile configuration (project ID, web API key, app ID) is an identifier, not a secret. Protect the project with the rules above, App Check if you enable it, API key restrictions in Google Cloud, and authorised domains in Firebase Authentication.
- Never put `GROQ_API_KEY`, service-account JSON, or `.env` files in the app or in Git.
- Serve everything over HTTPS. The hosting headers in `firebase/firebase.json` set a Content-Security-Policy, HSTS and related headers; it allows the web app to call the AI providers a learner can bring a key for (Groq, OpenAI, Anthropic, xAI, Mistral, DeepSeek, OpenRouter; Gemini is covered by Google's hosts) and no other AI host. A custom OpenAI-compatible server address works in the mobile and desktop apps but not in the strict-CSP web build; add your own origin only if you run the developer gateway.
