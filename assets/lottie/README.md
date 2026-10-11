# Sprichst Lottie animations

Eight animations drawn from the design-system tokens (coral, charcoal, cream), each in a `_light` and a `_dark` file. Backgrounds are transparent, and frame rate is 60 fps.

| File | Size | Length | Plays when | Reduced-motion fallback |
|---|---|---|---|---|
| `welcome_intro` | 512² | 2.2 s, once | The welcome screen first appears and the sign-in screen opens. The app mark assembles: sun, orbit, S, speech bubble, book pages, gate. | Show the last frame (the finished mark). |
| `nav_indicator` | 64×40 | 0.4 s, once | A navigation tab or rail item becomes selected. The accent-soft pill grows behind the icon. | Show the pill at full size. |
| `lesson_complete` | 200² | 1.4 s, once | The lesson summary opens. A coral disc appears, a check draws on, then a ring and six marks radiate. | Last frame. |
| `achievement_unlocked` | 200² | 1.6 s, once | A badge is earned (`Achievements`, e.g. *Wochenstreak*, *Volltreffer*). The badge pops on a coral disc, a star turns in and rays burst. | Last frame. |
| `streak_kept` | 240×120 | 1.6 s, once | The first study session of the day extends the streak (`ProgressTracker` streak rule). Six day marks fill, then today's mark pops in coral. | Last frame. |
| `answer_correct` | 48² | 0.6 s, once | An answer is checked and correct (with the "Correct" word, never alone). | Last frame. |
| `answer_incorrect` | 48² | 0.6 s, once | An answer is checked and wrong. A cross draws and shakes once. | Last frame, no shake. |
| `loading` | 88² | 1 s loop | Waiting for the AI provider, model download or sync. Always pair it with words. | Static ring with the arc at 12 o'clock. |

Choose the file by theme, for example `Theme.of(context).brightness == Brightness.dark ? 'assets/lottie/lesson_complete_dark.json' : 'assets/lottie/lesson_complete_light.json'`.

## Using them in Flutter

These files aren't wired up yet. To use them:

1. Add the `lottie` package to `pubspec.yaml` (pure Dart, no network access). Check its version against the project's Flutter SDK first.
2. List the folder under `flutter: assets:` as `- assets/lottie/`.
3. Play each animation once (`repeat: false`) and hide it from screen readers (`ExcludeSemantics`). The text beside it carries the meaning.
4. When `MediaQuery.disableAnimationsOf(context)` is true, jump to the last frame instead of playing.

## Regenerating

Run `python3 tool/lottie/gen_lottie.py assets/lottie` from the repository root. The palettes at the top of the script mirror the design-system tokens. Change those and regenerate rather than editing the JSON by hand.
