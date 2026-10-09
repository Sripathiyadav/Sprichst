# Security incident response

1. Detect and contain: revoke leaked keys (AI provider, Firebase service accounts), rotate secrets, take the AI server offline if needed, deploy tightened rules.
2. Assess within 24 hours: what data, how many people, risk to them. Record every incident, even small ones.
3. Notify the competent supervisory authority within 72 hours of becoming aware if there is a risk to people (GDPR Art. 33; UK ICO the same). Contact: [[SUPERVISORY_AUTHORITY]].
4. Notify affected users without undue delay if the risk is high (Art. 34), in plain language: what happened, what data, what to do, who to contact. Other jurisdictions (US state laws, Canada, Brazil, India, Australia) have their own deadlines: check them.
5. Fix the cause, add a regression test, update the records.
6. Post-mortem within 14 days.

Reporting vulnerabilities: see `SECURITY.md`.
