# Security Summary

Last updated: 8 October 2026

We design Sprichst to expose as little data as possible and to fail closed. This is a summary of the main measures; see SECURITY.md in the code repository for how to report a vulnerability.

## In the app

- No secret keys in the app. The Firebase web configuration is an identifier, not a secret; access is controlled by sign-in and the database rules below. AI-provider keys (for example Groq) exist only on the server.
- Inputs are cleaned and size-limited before they leave the device (control and invisible formatting characters removed; length caps for names, messages and learning context).
- No third-party scripts, fonts, analytics or session replay; a Content-Security-Policy restricts what the web app may load and contact.
- The web app is served with HSTS, no-sniff, frame denial, strict referrer and permissions policies.

## In the database (row-level security)

Cloud Firestore rules allow a signed-in user to read and write only their own documents. Every profile write is checked against a strict schema (allowed fields, types, ranges, enumerations and sizes). Everything else is denied by default, including all other users' data and Cloud Storage. The rules are covered by automated tests that run against the Firestore emulator.

## On the AI server

- Strict validation of every request: sizes, types, audio format (by content, not by file name), and body limits.
- Per-client rate limiting; optional requirement of a valid Firebase sign-in token.
- Generic error messages; no stack traces or provider details reach clients.
- Restricted cross-origin access (CORS), security headers.
- No raw SQL. The server has no SQL database, and an automated test fails the build if raw query building or string-built queries appear.

## Accounts and sign-in

Sign-in is handled by Google and Firebase Authentication. We never see or store your Google password.

## Incidents

If a breach affects personal data, we notify the competent authority within 72 hours where required by the GDPR, and you without undue delay where there is a high risk to you.
