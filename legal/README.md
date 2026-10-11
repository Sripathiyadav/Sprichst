# Legal and compliance documents

These documents cover privacy, terms, AI transparency, copyright and security for Sprichst. They are written as working templates for a small team and are **not legal advice**. Have a lawyer in your main market review them before launch.

## Before you publish

1. Fill every `[[PLACEHOLDER]]` (controller, addresses, contacts, copyright agent, regions, retention). `python3 scripts/check_legal_placeholders.py` lists what is left; `--strict` fails while any remain (use it in the release pipeline).
2. Register your DMCA designated agent at copyright.gov/dmca-directory (US$6, renewed every 3 years) if you serve US users.
3. Sign the Google Cloud / Firebase Data Processing Addendum and your AI provider's DPA; pick the Firestore region (an EU region for EU users is advisable).
4. Decide whether you need an EU/UK representative (GDPR Art. 27) and a data protection officer (Art. 37).
5. Complete `internal/` records; keep them current.

## User-facing documents (bundled into the app)

| File | Purpose |
|---|---|
| privacy-policy.md | GDPR, UK GDPR, FADP, CCPA/CPRA and other state laws, PIPEDA/Law 25, LGPD, DPDP, APAC |
| terms-of-service.md | Contract, acceptable use, liability, governing law |
| disclaimer.md | Not guaranteed results, AI limits, exam brands, no advice |
| ai-transparency.md | EU AI Act Art. 50, models, data flow, limits |
| cookies-and-storage.md | ePrivacy / TDDDG § 25: what is stored on the device |
| your-rights.md | How to use data rights, by region |
| copyright-and-takedown.md | DMCA § 512(c), DSA Art. 16, counter-notice, trademarks |
| impressum.md | German DDG § 5 provider information, DSA contact point |
| accessibility.md | European Accessibility Act statement |
| security-summary.md | Measures in the app, database and server |
| third-party-notices.md | Generated open-source and model licences |

## Internal records (not bundled)

| File | Purpose |
|---|---|
| internal/privacy-audit.md | Findings: fonts, third-party requests, analytics, session replay |
| internal/copyright-audit.md | Content and component provenance |
| internal/records-of-processing.md | GDPR Art. 30 record |
| internal/subprocessors.md | Recipients, roles, safeguards |
| internal/dpia-screening.md | Data protection impact assessment screening |
| internal/data-retention.md | Retention schedule |
| internal/dsar-procedure.md | Handling access, erasure and other requests |
| internal/incident-response.md | Breach handling, 72 hour notification |
| internal/release-checklist.md | What to verify before each release |
