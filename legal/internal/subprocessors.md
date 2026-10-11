# Recipients and processors

| Recipient | Role | Service | Data | Location | Safeguard | Action needed |
|---|---|---|---|---|---|---|
| Google Ireland Ltd / Google LLC | Processor | Firebase Authentication, Cloud Firestore, Firebase Hosting (if used) | Account, profile | Region [[FIRESTORE_REGION]] | Google Cloud DPA + SCCs, DPF | Accept the data processing terms in the Firebase console; set the Firestore location before first use (cannot be changed later). |
| Google (accounts) | Independent controller for the Google account | Sign-in | Sign-in data | Global | Google's privacy policy | Disclosed in the Privacy Policy |
| [[AI_SERVER_HOST]] | Processor (or you, if self-hosted) | Runs the AI gateway | Messages, IP | [[AI_SERVER_HOST_AND_COUNTRY]] | DPA with host | Sign a DPA with the host; set log retention |
| Groq, Inc. | Processor | LLM inference (optional) | Message, recent turns and learning summary | US | DPA, SCCs, no-training terms | Confirm retention / zero-data-retention settings in the Groq account |
| Hugging Face, Inc. and GitHub, Inc. | Independent (file hosts) | Model downloads | IP, requested file | US/EU | Their terms | Disclosed |

Rules: add a row and update the Privacy Policy before connecting any new service. No analytics, advertising or error-reporting service may be added without a documented review.
