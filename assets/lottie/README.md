# Sprichst Lottie animations

Fourteen animations (plus five for the tour) drawn from the design-system tokens (coral, charcoal, cream), each in a `_light` and a `_dark` file. Backgrounds are transparent, and frame rate is 60 fps.

| File | Size | Length | Plays when | Reduced-motion fallback |
|---|---|---|---|---|
| `welcome_intro` | 512² | 1.8 s, once | The welcome screen first appears and the sign-in screen opens. The orbit mark assembles: the orbit swings in, the S is revealed from its centre and the disc lands on the orbit. | Show the last frame (the finished mark). |
| `nav_indicator` | 64×40 | 0.4 s, once | A navigation tab or rail item becomes selected. The accent-soft pill grows behind the icon. | Show the pill at full size. |
| `lesson_complete` | 200² | 1.4 s, once | The lesson summary opens. A coral disc appears, a check draws on, then a ring and six marks radiate. | Last frame. |
| `achievement_unlocked` | 200² | 1.6 s, once | A badge is earned (`Achievements`, e.g. *Wochenstreak*, *Volltreffer*). The badge pops on a coral disc, a star turns in and rays burst. | Last frame. |
| `streak_kept` | 240×120 | 1.6 s, once | The first study session of the day extends the streak (`ProgressTracker` streak rule). Six day marks fill, then today's mark pops in coral. | Last frame. |
| `answer_correct` | 48² | 0.6 s, once | An answer is checked and correct (with the "Correct" word, never alone). | Last frame. |
| `answer_incorrect` | 48² | 0.6 s, once | An answer is checked and wrong. A cross draws and shakes once. | Last frame, no shake. |
| `loading` | 88² | 1 s loop | Waiting for the AI provider, model download or sync. Always pair it with words. | Static ring with the arc at 12 o'clock. |
| `empty_state` | 96² | 1.2 s, once | `StateMessage` with kind `empty`. An open book settles. | Last frame. |
| `error_state` | 96² | 1.2 s, once | `StateMessage` with kind `error`. A warning triangle shakes once. | Last frame, no shake. |
| `offline_state` | 96² | 1.2 s, once | `StateMessage` with kind `offline`. A cloud is crossed out. | Last frame. |
| `level_up` | 72² | 1.2 s, once | The lesson summary when a new level is reached. | Last frame. |
| `coach_thinking` | 56×28 | 1.2 s loop | In the coach's send button while a reply is on its way. | First dots, still. |
| `download_model` | 40² | 1 s loop | Next to a model's progress bar while it downloads. | Still arrow. |

Choose the file by theme, for example `Theme.of(context).brightness == Brightness.dark ? 'assets/lottie/lesson_complete_dark.json' : 'assets/lottie/lesson_complete_light.json'`.

## Using them in Flutter

`SprichstLottie('name')` (`lib/shared/widgets/lottie_view.dart`) picks the light or dark file, hides the animation from screen readers and, under reduced motion, shows a still frame instead of playing. It is used by the welcome screen (`welcome_intro`), the tour (`tour_*`), the lesson summary (`lesson_complete`, `level_up`, `streak_kept`), answer feedback (`answer_correct`, `answer_incorrect`), badge news (`achievement_unlocked`), the navigation bar and rail (`nav_indicator`), empty, error and offline states, the coach send button and model downloads. `loading` is kept for places where a words-plus-spinner state needs it.

Tour animations (240x180, 3 s, play once): `tour_lessons`, `tour_coach`, `tour_review`, `tour_private`, `tour_design`.

## Regenerating

Run `python3 tool/lottie/gen_lottie.py assets/lottie` from the repository root. The palettes at the top of the script mirror the design-system tokens. Change those and regenerate rather than editing the JSON by hand.
