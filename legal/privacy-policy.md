# Privacy Policy

Last updated: 8 October 2026

This policy explains what personal data Sprichst ("the app", "we") handles when you learn German with it, why, who else receives it, how long it is kept, and what rights you have. We wrote it to be read, not to hide things. The short version:

- We do not use analytics, advertising, tracking, or session-replay tools. Nobody records your screen or follows you around the web.
- Your learning progress is stored in your account so it follows you between devices. Nothing else about you is collected on purpose.
- The AI tutor can run on your own phone. If you use the AI server (always the case in a web browser), your messages go to it and, from there, to an AI provider.
- Your voice is never stored by us. Recordings are turned into text and thrown away.
- You can export or erase everything from inside the app.

## 1. Who is responsible

The controller of your personal data is:

[[CONTROLLER_NAME]]
[[CONTROLLER_ADDRESS]]
Email: [[PRIVACY_EMAIL]]

Contact for privacy questions: [[PRIVACY_CONTACT]] (if we have appointed a data protection officer, they are named here: [[DPO_NAME_OR_NONE]]).

[[EU_UK_REPRESENTATIVE_OR_NONE]]

## 2. What we handle, why, and on what legal basis

For people in the EU, EEA, UK and Switzerland, "legal basis" means the grounds the GDPR requires. For everyone else it simply explains why we need the data.

Account sign-in. When you press "Continue with Google", Google tells us your account identifier, email address and display name through Firebase Authentication. We use them to create and recognise your account. Legal basis: performing our contract with you (Art. 6(1)(b) GDPR).

Your learning profile. This is what the app needs to teach you: your name or nickname, your level and goal, lessons completed, answers and accuracy per skill, mistakes to review, flashcard schedules, game scores, badges, daily quests, your streak, and your settings (appearance, voice, reminders, AI preferences). It is stored in Cloud Firestore under your account and cached on your device. Legal basis: performing our contract with you (Art. 6(1)(b)).

Messages to the AI tutor. When you write or speak to the coach, we send your message, the last few messages of the current conversation (up to eight, kept only in memory and forgotten when you leave the coach screen) and a short summary of your learning state (your level, current lesson, weak skills, a few words you know and recent mistakes) so the answer fits you. This summary never contains your name or email. Legal basis: performing our contract with you (Art. 6(1)(b)); you choose whether to use the tutor.

Your voice. If you use voice features, the microphone is used only while you record or while voice mode is on. The audio is turned into text, on your device or on the AI server, and then discarded. Recordings are not kept or used to train anything. Legal basis: performing our contract with you; the device asks for your permission first.

Technical data on the AI server. When the app talks to the AI server, the server's operator sees your IP address and the time and type of each request, which is normal for any internet service. Request logs are kept for [[LOG_RETENTION_DAYS]] days for security and to stop abuse. If sign-in checking is switched on, the server also sees a verified account identifier. Legal basis: our legitimate interest in keeping the service secure and preventing abuse (Art. 6(1)(f)).

Downloads you ask for. If you download on-device AI models, your device connects to Hugging Face or GitHub, which can see your IP address and the file requested. This happens only when you tap download.

Legal obligations. We may keep the information needed to answer legal claims, copyright notices and requests from authorities. Legal basis: a legal obligation or our legitimate interest in defending legal claims (Art. 6(1)(c) and (f)).

What we do not do. We do not sell or rent your data. We do not share it for advertising. We do not build advertising profiles. We do not make decisions about you that have legal or similarly significant effects, and the app's lesson recommendations are suggestions you can ignore (so Art. 22 GDPR does not apply).

## 3. What the web version contacts

When you open the web app, your browser loads everything from our own server. The renderer, the fonts (Roboto, bundled) and the Firebase code are all served from the same address, so no third party learns that you visited. Nothing is sent to Google, a font service or a tracking service just because a page opened.

Google's servers are contacted only when you act: pressing "Continue with Google" opens Google's sign-in and Firebase's sign-in frame, and signing in or saving progress talks to Firebase and Cloud Firestore. See section 5.

## 4. Cookies and similar storage

We use no advertising or analytics cookies. We store only what the app needs to work: your sign-in session and a copy of your progress and settings on your device, and the AI server address you set. This is "strictly necessary" storage, so no consent banner is needed. The details are in the Cookies and Storage notice.

## 5. Who receives your data

Google (Firebase Authentication and Cloud Firestore). Google Ireland Limited provides these services in the EEA and UK, and Google LLC in the United States, acting as our processor for your account and learning profile. The data is stored in the location [[FIRESTORE_REGION]]. Google's own privacy information applies to the Google account you sign in with.

The AI server host. Our AI server runs at [[AI_SERVER_HOST_AND_COUNTRY]]. It receives the messages and summary described above only when you use it. It is operated by [[CONTROLLER_NAME]].

AI model provider. When the AI server is set to use Groq's hosted models, your message, recent conversation and learning summary are passed to Groq, Inc. (United States) to generate the reply. Groq acts as our processor and must not use the data for its own purposes. [[CONFIRM_GROQ_DATA_RETENTION_AND_TRANSFER_TERMS]] If you choose "This phone only" in Account → AI & voice, nothing is sent to the server or to Groq. In the default "Automatic" setting, the server is used only for anything not yet downloaded to your phone. In a web browser the models cannot run, so the web version always uses the AI server.

Hugging Face and GitHub. Receive your IP address when you download on-device models (see section 2).

Authorities and advisers. We may disclose data if the law requires it, or to professional advisers under confidentiality.

We do not use other analytics, advertising or tracking recipients.

## 6. Transfers outside your country

Google and Groq process data in the United States and other countries. Where the GDPR or UK GDPR applies, we rely on an adequacy decision (such as the EU-US Data Privacy Framework for certified recipients) or on the European Commission's Standard Contractual Clauses, together with the UK addendum where needed, and on additional safeguards. You can ask us for a copy of the safeguards at [[PRIVACY_EMAIL]].

## 7. How long we keep data

Account and learning profile: until you erase them or delete your account. Erasing removes the documents from our database straight away; backups made by Google expire on Google's normal schedule.

Voice recordings: never stored. Message text on the AI server: not stored by us after the reply is sent. The AI provider's own retention is described in section 5.

Server logs: [[LOG_RETENTION_DAYS]] days.

Copyright and legal-claim records: as long as needed for the claim, then deleted.

On-device data stays until you reset progress, sign out and clear data, or uninstall the app.

## 8. Your rights

Depending on where you live, you have the right to access your data, correct it, erase it, restrict or object to its processing, receive it in a portable format, withdraw consent, and complain to a data protection authority. In the app you can:

- Export everything: Account → Privacy & data → Export my data (copies your profile as JSON).
- Reset learning progress: Account → Danger zone → Reset learning progress.
- Delete your account and learning data: Account → Danger zone → Delete account.

For anything else, write to [[PRIVACY_EMAIL]]. We will answer within one month (45 days in California, extendable where the law allows) and will not charge you except for clearly excessive requests. We may need to confirm that you are the account holder. See also "Your Rights" for the full list by region.

## 9. Children

Sprichst is for people aged 16 and over, or the age of digital consent in your country if that is lower, and in India for people aged 18 and over. Younger learners need a parent or guardian to set up the account and agree to this policy on their behalf. We do not knowingly collect data from children below those ages. If you think a child has given us data, contact [[PRIVACY_EMAIL]] and we will delete it. The app contains no advertising, no tracking and no public chat for anyone.

## 10. Security

We protect your data with measures suited to the risk: encrypted connections, per-account access rules in the database (no one else's account can read yours), strict validation of what is sent to our servers, rate limits, optional sign-in checks on the AI server, no secret keys inside the app, and no raw database queries. See the Security summary. No system is perfectly secure; if a breach affects you, we will tell you and the authorities as the law requires.

## 11. Regional information

European Economic Area and United Kingdom. The controller is named in section 1. You can complain to your national data protection authority; in the UK that is the Information Commissioner's Office. Our lead supervisory authority is [[SUPERVISORY_AUTHORITY]].

Switzerland. We apply the revised Federal Act on Data Protection. You can contact the Federal Data Protection and Information Commissioner.

California and other US states. We do not sell or share personal information, we do not use it for targeted advertising, and we do not use or disclose sensitive personal information beyond providing the service. We collect these categories: identifiers (account identifier, email, name), internet activity inside the app (your learning activity), audio (voice recordings, which are discarded after transcription), and inferences (your weak skills and recommendations). You may request to know, delete, correct and limit use of your data, and we will not discriminate against you for doing so. Send requests to [[PRIVACY_EMAIL]]; an authorised agent may act for you. If we deny a request, you can appeal by replying to that decision. We also honour browser Global Privacy Control signals, although we have nothing to opt you out of. Residents of Virginia, Colorado, Connecticut, Texas and other states with similar laws have comparable rights.

Canada. We handle personal information in line with PIPEDA and, in Quebec, Law 25. You may ask to access or correct it and can complain to the Office of the Privacy Commissioner of Canada or your provincial regulator.

Brazil. Under the LGPD you have the rights in Art. 18, including confirmation of processing, access, correction, anonymisation or deletion, portability and information about sharing. You can complain to the ANPD.

India. We are preparing to meet the Digital Personal Data Protection Act, 2023 as its provisions take effect. You may ask to access, correct or erase your data, nominate someone to exercise your rights if you die or become incapacitated, and use our grievance contact, [[GRIEVANCE_OFFICER]]. If you are under 18, a parent or guardian must agree on your behalf.

Australia, Japan, South Korea, South Africa and elsewhere. We apply the same protections to everyone and will respect your rights under local law, such as the Australian Privacy Principles, Japan's APPI, Korea's PIPA and South Africa's POPIA.

## 12. Changes

If we change this policy in a meaningful way we will tell you in the app before it applies, and show the date above. Earlier versions are available on request.

## 13. Contact

[[CONTROLLER_NAME]], [[CONTROLLER_ADDRESS]], [[PRIVACY_EMAIL]].
