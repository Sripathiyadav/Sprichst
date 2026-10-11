# Security Summary

Last updated: 8 October 2026

We design Sprichst to expose as little data as possible and to fail closed. This is a summary of the main measures; see SECURITY.md in the code repository for how to report a vulnerability.

## In the app

- No secret keys of ours in the app. The Firebase web configuration is an identifier, not a secret; access is controlled by sign-in and the database rules below. If you add your own AI provider key, it is kept in your device's secure storage, shown only masked, never logged, never synced and never part of your profile. Anyone who can unlock your device could use it, so you can remove it in the app and revoke it in your provider's console any time.
- Inputs are cleaned and size-limited before they leave the device (control and invisible formatting characters removed; length caps for names, messages and learning context).
- No third-party scripts, fonts, analytics or session replay; a Content-Security-Policy restricts what the web app may load and contact.
- The web app is served with HSTS, no-sniff, frame denial, strict referrer and permissions policies.

## In the database (row-level security)

Cloud Firestore rules allow a signed-in user to read and write only their own documents. Every profile write is checked against a strict schema (allowed fields, types, ranges, enumerations and sizes). Everything else is denied by default, including all other users' data and Cloud Storage. The rules are covered by automated tests that run against the Firestore emulator.

## Talking to your AI provider

Requests go from your device straight to the provider you chose over HTTPS (a custom server address must start with https://, so a key never travels in the clear) with a timeout, the minimum text needed, and no identifying details (no name or email). Errors are turned into plain messages that never contain your key or your words. A provider problem (limit reached, no credit, offline, rejected key, unknown model) is reported to you and never causes the app to send your message somewhere else on its own. There is no Sprichst-operated AI server, so there is no server to attack, no request log, and no shared provider key. (The repository still contains a developer-only gateway in `ai-server/`, hardened and tested, that is not part of the released app.)

## Accounts and sign-in

Sign-in is handled by Google and Firebase Authentication. We never see or store your Google password.

## Incidents

If a breach affects personal data, we notify the competent authority within 72 hours where required by the GDPR, and you without undue delay where there is a high risk to you.
