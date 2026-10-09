# Records of processing activities (GDPR Art. 30)

Controller: [[CONTROLLER_NAME]], [[CONTROLLER_ADDRESS]], [[PRIVACY_EMAIL]]. DPO / representative: [[DPO_NAME_OR_NONE]] / [[EU_UK_REPRESENTATIVE_OR_NONE]].
Last reviewed: 8 October 2026. Review at least yearly and on every change in data flows.

| # | Activity | Purpose | Data subjects | Categories of data | Recipients | Third-country transfer | Retention | Legal basis |
|---|---|---|---|---|---|---|---|---|
| 1 | Account sign-in | Create and recognise the account | Learners | Google account ID, email, display name | Google (Firebase Authentication) | US (SCCs / DPF) | Until account deletion | Art. 6(1)(b) |
| 2 | Learning profile | Personalised learning, sync between devices | Learners | Name or nickname, level, goal, progress, answers, mistakes, flashcards, scores, settings | Google (Cloud Firestore, region [[FIRESTORE_REGION]]) | Per region; US support access (SCCs) | Until erasure or account deletion | Art. 6(1)(b) |
| 3 | AI tutor on the learner's own Groq account (optional) | Answer and correct the learner's messages | Learners | Message text, up to 8 recent conversation turns, learning summary (no name or email), optional audio | Groq, Inc., contracted by the learner directly; Sprichst receives nothing | US (made by the learner) | Not received by Sprichst; Groq's own terms apply | Art. 6(1)(b) (the learner's choice) |
| 4 | Speech | Transcribe and speak | Learners | Audio recording | On-device, or Groq Whisper with the learner's own key (Sprichst receives nothing) | none on-device | Discarded after processing | Art. 6(1)(b) and device permission |
| 5 | Groq API key | Lets the app call Groq as the learner | Learners who add one | The key | Device secure storage only; never sent to Sprichst | none | Until the learner removes it | Art. 6(1)(b) |
| 6 | Model downloads | Offline AI | Learners (on request) | IP address seen by Hugging Face / GitHub | Hugging Face, GitHub | US | Per their policies | Art. 6(1)(b) |
| 7 | Legal claims and notices | Copyright notices, rights requests | Complainants, users | Contact details, notice contents | Advisers if needed | none | As needed, max 3 years after closure | Art. 6(1)(c)/(f) |

Security measures (Art. 32): see `legal/security-summary.md`.
