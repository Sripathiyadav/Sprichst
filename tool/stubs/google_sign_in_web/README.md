# google_sign_in_web (privacy stub)

`pubspec.yaml` replaces the real `google_sign_in_web` with this package through
`dependency_overrides`. It registers nothing, so the web build never loads
Google Identity Services at start-up. See the comment in `lib/`.

If you ever need `google_sign_in` on the web, remove the override and the stub,
and load the plugin only after the person has agreed (for example by initialising
it lazily), then update `legal/privacy-policy.md`.
