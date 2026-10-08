# On-device AI

The AI Coach runs on the phone itself. The learner downloads the models once
(Account → AI & voice → On-device AI) and from then on the coach works with no
internet: chat, corrections, speech recognition and the tutor's voice. Nothing
the learner says or writes leaves the phone. The AI server is optional.

| Job | Engine | Code |
| --- | --- | --- |
| Tutor (chat, corrections) | llama.cpp via [`llamadart`](https://pub.dev/packages/llamadart), GGUF models | `lib/data/on_device/on_device_runtime_io.dart` |
| Speech recognition | Whisper via [`sherpa_onnx`](https://pub.dev/packages/sherpa_onnx) | same |
| Tutor voice | Piper voices via `sherpa_onnx` (the same voices the server offers) | same |

## Models

| Tutor | Download | Licence | Recommended when the phone has |
| --- | --- | --- | --- |
| Light (Qwen2.5 0.5B) | 491 MB | Apache 2.0 | under 3 GB |
| Balanced (Gemma 3 1B) | 806 MB | Gemma terms | 3–5 GB |
| Better (Qwen2.5 1.5B) | 1.1 GB | Apache 2.0 | 5–7 GB |
| Best (Gemma 3 4B) | 2.5 GB | Gemma terms | 7 GB or more |

Speech recognition: Whisper tiny (104 MB) or base (160 MB, recommended from
3 GB). Voices: 26–115 MB each, picked in AI & voice → Voice.

The app reads the phone's memory and marks the best tutor for it ("Best for this
phone"); the learner can choose any model, and models too big for the phone are
flagged. Simulators and emulators are capped at Balanced: they run on the CPU
only. Qwen2.5 3B is left out because its licence does not allow commercial use.

The catalogue (`lib/data/on_device/model_catalogue.dart`) lists every file with
its exact size; downloads resume after an interruption and a model only counts
as installed once every file has arrived (a `.complete` marker).

## Where the tutor runs

The learner's "Where the tutor runs" setting (AI & voice) picks the route, see
`lib/data/ai/hybrid_ai_repository.dart`:

- **Automatic** (default): the phone; the AI server only for something not
  downloaded yet.
- **AI server first**: better answers when the server can be reached, the phone
  when it cannot.
- **This phone only**: nothing ever leaves the device.

## How the small models are kept honest

Phone-sized models make more mistakes than the server's model, so:

- Replies are constrained to a JSON schema (llama.cpp grammar), so they always
  parse. In chat the corrected sentence is generated *before* the reply; small
  models otherwise fold the correction into the reply and report none.
- A "correction" that keeps less than half of the learner's words (a
  translation, a different sentence) is discarded.
- Every explanation starts with the exact change (`"ein" → "einen".`), which is
  always right, followed by the model's reason, which can be wrong on small
  models.

Measured on five learner sentences (iOS simulator): Gemma 3 1B caught all four
mistakes and left the correct sentence alone; Qwen2.5 1.5B caught three of
four; Qwen2.5 0.5B is inconsistent. Grammar *reasons* are the weak spot of all
of them, Gemma 3 4B included.

## Platform notes

- **iOS 16.4+, macOS 14+** (llamadart's minimum).
- **Storage**: models live in `Application Support/models/`. On iOS the
  AppDelegate excludes that folder from iCloud backup (Apple requires it for
  re-downloadable data).
- **espeak path limit**: Piper's phonemiser (espeak-ng) ignores a data path of
  256 characters or more, and sherpa-onnx then ends the app. The shared
  `models/espeak-ng-data` folder keeps the path short (212 characters on the
  iOS simulator, the longest case), and the runtime checks the files and path
  before creating a voice so a problem is an error message, not a crash.
- **Android**: arm64 only for the native libraries. In-memory audio plays
  through a loopback proxy, allowed by `res/xml/network_security_config.xml`.
- **Web**: models cannot run in a browser; the web build uses the AI server.

## Building for iOS: keychain prompt

The first iOS build downloads llama.cpp's XCFramework through Swift Package
Manager. If you have a github.com password saved in the macOS keychain,
SwiftPM asks to read it and **the build waits silently until you answer the
keychain dialog** (choose Deny or Always Allow). If no dialog is visible, run
once from the project root:

```bash
cd ~/Library/Caches && mkdir -p spm-warm && cd spm-warm && \
  cp -R ~/.pub-cache/hosted/pub.dev/llamadart_llama_cpp_flutter-0.0.19/darwin/llamadart_llama_cpp_flutter/. . && \
  swift package resolve --disable-keychain && cd .. && rm -rf spm-warm
```

That fills SwiftPM's shared download cache, and the Xcode build then uses it.

## Verified

On the iPhone 17 Pro simulator and an Android 15 (API 35) emulator: download,
chat, correction, speech, playback and transcription all on the device. On
Android the same run was repeated in airplane mode (network unreachable) and
everything still worked.
