# DPIA screening (GDPR Art. 35)

Date: 8 October 2026. Reviewer: [[REVIEWER]].

Criteria from the EDPB guidelines (a DPIA is usually needed when two or more apply):

| Criterion | Applies? | Why |
|---|---|---|
| Evaluation or scoring | Partly | Skill and readiness estimates for learning only, no effect on rights |
| Automated decisions with legal or similar effect | No | |
| Systematic monitoring | No | No tracking or analytics; no replay |
| Sensitive data | No | Voice is not used for identification (no biometric templates); learners are not asked for health or similar data |
| Large scale | Not yet | Re-assess if users exceed about 100,000 |
| Matching or combining datasets | No | |
| Vulnerable subjects | Possible | Minors may learn with guardians; no ads, tracking, public chat |
| Innovative technology | Yes | Language models and speech, mostly on-device |
| Prevents exercising rights | No | |

Result: one criterion plus a possible one; a full DPIA is not required now. Mitigations already built in: on-device processing as default, no name or email in AI prompts, transient audio, strict database rules, minimal retention. Re-run the screening before adding any feature that profiles users, shares content between users, uses voice for identity, or targets children.
