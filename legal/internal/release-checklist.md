# Release checklist (privacy, security and legal)

Run before every public release.

- [ ] `python3 scripts/check_legal_placeholders.py --strict` passes (no `[[...]]` left).
- [ ] `python3 scripts/generate_third_party_notices.py --check` passes.
- [ ] `python3 scripts/vendor_web_deps.py --check` passes.
- [ ] `flutter test` passes (includes the privacy, security, input-validation and rules-fixture tests).
- [ ] `cd firebase && npm test` passes (Firestore and Storage rules in the emulator).
- [ ] `cd ai-server && python3 -m pytest` passes.
- [ ] `flutter build web --release`, then open the site with the browser's network panel: only your own origin is contacted until sign-in is pressed.
- [ ] Hosting config: replace `__AI_GATEWAY_ORIGIN__` in `firebase/firebase.json` with the real AI server origin before `firebase deploy`.
- [ ] Rules deployed: `firebase deploy --only firestore:rules,storage`.
- [ ] AI server: `AUTH_REQUIRED=1`, `FIREBASE_PROJECT_ID`, `CORS_ORIGINS` and `RATE_LIMIT_PER_MINUTE` set; HTTPS in front.
- [ ] No keys in the repository (guard test) and no `.env` committed.
- [ ] DMCA agent registered and current; Impressum complete.
- [ ] New third-party service? Update Privacy Policy, subprocessors, records of processing.
