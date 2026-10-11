# Recipients and processors

| Recipient | Role | Service | Data | Location | Safeguard | Action needed |
|---|---|---|---|---|---|---|
| Google Ireland Ltd / Google LLC | Processor | Firebase Authentication, Cloud Firestore, Firebase Hosting (if used) | Account, profile | Region [[FIRESTORE_REGION]] | Google Cloud DPA + SCCs, DPF | Accept the data processing terms in the Firebase console; set the Firestore location before first use (cannot be changed later). |
| Google (accounts) | Independent controller for the Google account | Sign-in | Sign-in data | Global | Google's privacy policy | Disclosed in the Privacy Policy |
| Groq, Inc.; Google (Gemini); OpenAI; Anthropic; xAI; Mistral AI; DeepSeek; OpenRouter, Inc.; or a custom OpenAI-compatible server | Independent provider chosen by the learner (not our processor) | LLM (and, for Groq and OpenAI, Whisper) inference with the learner's own API key | What the learner sends: message, recent turns, learning summary, audio | Varies, mostly US | Learner's own agreement with the provider; Sprichst receives nothing | Disclose in the Privacy Policy (done); no DPA needed because no provider processes data on our behalf. Revisit if you ever call a provider with a Sprichst-owned key. |
| Hugging Face, Inc. and GitHub, Inc. | Independent (file hosts) | Model downloads | IP, requested file | US/EU | Their terms | Disclosed |

Rules: add a row and update the Privacy Policy before connecting any new service. No analytics, advertising or error-reporting service may be added without a documented review.
