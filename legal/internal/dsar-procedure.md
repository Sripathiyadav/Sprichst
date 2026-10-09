# Handling data subject requests

1. Receive at [[PRIVACY_EMAIL]]. Log date received (the clock starts: 1 month GDPR, 45 days CCPA).
2. Confirm identity: reply must come from the account's Google email or be verified by signing in. Never send data to an unverified address.
3. Act:
   - Access / portability: export the user's Firestore documents as JSON (the in-app export covers the profile).
   - Rectification: edit fields or ask the user to.
   - Erasure: delete the user in Firebase Authentication and the `users/{uid}` tree.
   - Restriction / objection: stop optional processing: the learner can switch to "This phone only" and remove the Groq key in the app (we hold neither the key nor their Groq data).
4. Reply within the deadline; extend once by two months only for complexity, and tell the user why within the first month.
5. Record the request, the action and the date for 3 years.
6. Requests from a guardian for a child: confirm the relationship reasonably.
