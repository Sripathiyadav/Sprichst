# Retention schedule

| Data | Period | How deleted |
|---|---|---|
| Learning profile (Firestore `users/{uid}` and children) | Until the user deletes the account or resets progress | In-app deletion removes documents, then the Firebase Auth user |
| Firebase Authentication record | Until the user deletes the account | In-app deletion |
| Google backups of deleted data | Google schedule (about 180 days) | Expire automatically |
| Voice audio | Not stored by Sprichst | Discarded after transcription |
| AI message text | Never received by Sprichst (phone, or straight to the learner's chosen provider with their key) | |
| AI provider API keys | Until the learner removes it; device secure storage only | Remove button, or uninstall |
| Rights requests and copyright notices | 3 years after closure | Manual |
| On-device cache | Until reset, sign-out and clear, or uninstall | User |

Inactive accounts: [[INACTIVE_ACCOUNT_POLICY, for example delete after 24 months of inactivity with a prior email notice]].
