# Retention schedule

| Data | Period | How deleted |
|---|---|---|
| Learning profile (Firestore `users/{uid}` and children) | Until the user deletes the account or resets progress | In-app deletion removes documents, then the Firebase Auth user |
| Firebase Authentication record | Until the user deletes the account | In-app deletion |
| Google backups of deleted data | Google schedule (about 180 days) | Expire automatically |
| Voice audio | Not stored | Discarded after transcription |
| AI message text on the server | Not stored | |
| Server access logs | [[LOG_RETENTION_DAYS]] days (recommended 14 to 30) | Log rotation on the host |
| Rights requests and copyright notices | 3 years after closure | Manual |
| On-device cache | Until reset, sign-out and clear, or uninstall | User |

Inactive accounts: [[INACTIVE_ACCOUNT_POLICY, for example delete after 24 months of inactivity with a prior email notice]].
