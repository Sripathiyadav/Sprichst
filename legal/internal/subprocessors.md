# Recipients and processors

| Recipient | Role | Service | Data | Location | Safeguard | Action needed |
|---|---|---|---|---|---|---|
| Google Ireland Ltd / Google LLC | Processor | Firebase Authentication, Cloud Firestore, Firebase Hosting (if used) | Account, profile | Region [[FIRESTORE_REGION]] | Google Cloud DPA + SCCs, DPF | Accept the data processing terms in the Firebase console; set the Firestore location before first use (cannot be changed later). |
| Google (accounts) | Independent controller for the Google account | Sign-in | Sign-in data | Global | Google's privacy policy | Disclosed in the Privacy Policy |
| Groq, Inc. | Independent provider chosen by the learner (not our processor) | LLM and Whisper inference with the learner's own API key | What the learner sends: message, recent turns, learning summary, audio | US | Learner's own agreement with Groq; Sprichst receives nothing | Disclose in the Privacy Policy (done); no DPA needed because Groq does not process data on our behalf. Revisit if you ever call Groq with a Sprichst-owned key. |
| Hugging Face, Inc. and GitHub, Inc. | Independent (file hosts) | Model downloads | IP, requested file | US/EU | Their terms | Disclosed |

Rules: add a row and update the Privacy Policy before connecting any new service. No analytics, advertising or error-reporting service may be added without a documented review.
