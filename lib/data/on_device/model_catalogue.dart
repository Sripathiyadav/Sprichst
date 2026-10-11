/// The models Sprichst can download and run on the phone itself.
///
/// Everything here is downloaded once and then works with no internet.
/// Licences are all commercial-use friendly (Apache 2.0, Gemma terms, CC0,
/// open data); Qwen2.5 3B is left out because its licence is research-only.
library;

enum ModelKind { tutor, speechRecognition, voice }

/// One file to fetch. [archive] files are tar.bz2 and are unpacked in place.
class ModelFile {
  const ModelFile(this.url, this.name, this.bytes, {this.archive = false});

  final String url;
  final String name;
  final int bytes;
  final bool archive;
}

class OnDeviceModel {
  const OnDeviceModel({
    required this.id,
    required this.kind,
    required this.label,
    required this.description,
    required this.license,
    required this.files,
    this.minRamMb = 0,
  });

  final String id;
  final ModelKind kind;
  final String label;
  final String description;
  final String license;
  final List<ModelFile> files;

  /// Below this much RAM the model is likely to be killed by the OS or crawl.
  final int minRamMb;

  int get downloadBytes => files.fold(0, (sum, f) => sum + f.bytes);
}

const _hf = 'https://huggingface.co';
const _sherpaTts =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models';

/// Tutor models, smallest first.
const tutorModels = <OnDeviceModel>[
  OnDeviceModel(
    id: 'qwen2.5-0.5b',
    kind: ModelKind.tutor,
    label: 'Light (Qwen2.5 0.5B)',
    description:
        'Fast and small; runs on almost any phone. Corrections are often shallow and sometimes wrong.',
    license: 'Apache 2.0',
    minRamMb: 2048,
    files: [
      ModelFile(
          '$_hf/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
          'model.gguf',
          491400032),
    ],
  ),
  OnDeviceModel(
    id: 'gemma-3-1b',
    kind: ModelKind.tutor,
    label: 'Balanced (Gemma 3 1B)',
    description:
        'Good multilingual model at a moderate size. A solid choice for most phones.',
    license: 'Gemma terms of use',
    minRamMb: 3072,
    files: [
      ModelFile(
          '$_hf/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf',
          'model.gguf',
          806058272),
    ],
  ),
  OnDeviceModel(
    id: 'qwen2.5-1.5b',
    kind: ModelKind.tutor,
    label: 'Better (Qwen2.5 1.5B)',
    description:
        'Clearly better German explanations. Best on phones with 6 GB of memory or more.',
    license: 'Apache 2.0',
    minRamMb: 4096,
    files: [
      ModelFile(
          '$_hf/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
          'model.gguf',
          1117320736),
    ],
  ),
  OnDeviceModel(
    id: 'gemma-3-4b',
    kind: ModelKind.tutor,
    label: 'Best (Gemma 3 4B)',
    description:
        'The most capable tutor that fits on a phone. Needs a recent high-end phone with 8 GB of memory.',
    license: 'Gemma terms of use',
    minRamMb: 7168,
    files: [
      ModelFile(
          '$_hf/unsloth/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf',
          'model.gguf',
          2489894016),
    ],
  ),
];

/// Whisper models for understanding what the learner says.
const speechRecognitionModels = <OnDeviceModel>[
  OnDeviceModel(
    id: 'whisper-tiny',
    kind: ModelKind.speechRecognition,
    label: 'Fast (Whisper tiny)',
    description: 'Quick, but misses more words, especially from beginners.',
    license: 'MIT',
    files: [
      ModelFile(
          '$_hf/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-encoder.int8.onnx',
          'encoder.onnx',
          12937772),
      ModelFile(
          '$_hf/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-decoder.int8.onnx',
          'decoder.onnx',
          89855401),
      ModelFile(
          '$_hf/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-tokens.txt',
          'tokens.txt',
          816730),
    ],
  ),
  OnDeviceModel(
    id: 'whisper-base',
    kind: ModelKind.speechRecognition,
    label: 'Accurate (Whisper base)',
    description: 'Understands learners noticeably better. Recommended.',
    license: 'MIT',
    minRamMb: 3072,
    files: [
      ModelFile(
          '$_hf/csukuangfj/sherpa-onnx-whisper-base/resolve/main/base-encoder.int8.onnx',
          'encoder.onnx',
          29120534),
      ModelFile(
          '$_hf/csukuangfj/sherpa-onnx-whisper-base/resolve/main/base-decoder.int8.onnx',
          'decoder.onnx',
          130672026),
      ModelFile(
          '$_hf/csukuangfj/sherpa-onnx-whisper-base/resolve/main/base-tokens.txt',
          'tokens.txt',
          816730),
    ],
  ),
];

OnDeviceModel _voice(String id, int bytes) => OnDeviceModel(
      id: id,
      kind: ModelKind.voice,
      label: id,
      description: '',
      license: '',
      files: [
        ModelFile('$_sherpaTts/vits-piper-$id.tar.bz2', 'voice.tar.bz2', bytes,
            archive: true),
      ],
    );

/// Piper voices, keyed by the same ids the gateway and voice picker use.
final voiceModels = <String, OnDeviceModel>{
  for (final v in [
    _voice('de_DE-thorsten-medium', 67214254),
    _voice('de_DE-thorsten-high', 115591546),
    _voice('de_DE-thorsten_emotional-medium', 80215792),
    _voice('de_DE-kerstin-low', 67107768),
    _voice('de_DE-ramona-low', 67084795),
    _voice('de_DE-karlsson-low', 67100500),
    _voice('de_DE-eva_k-x_low', 26521242),
  ])
    v.id: v,
};

/// Speaker names inside multi-speaker Piper voices.
const voiceSpeakers = {'de_DE-thorsten_emotional-medium': 'neutral'};

OnDeviceModel? findModel(String id) {
  for (final m in [...tutorModels, ...speechRecognitionModels]) {
    if (m.id == id) return m;
  }
  return voiceModels[id];
}

/// The tutor model that suits a phone with [ramMb] of memory: the biggest one
/// that leaves the OS and app enough room. Null RAM (unknown) gets Balanced.
OnDeviceModel recommendedTutor(int? ramMb) {
  if (ramMb == null) return tutorModels[1];
  if (ramMb >= 7168) return tutorModels[3];
  if (ramMb >= 5120) return tutorModels[2];
  if (ramMb >= 3072) return tutorModels[1];
  return tutorModels[0];
}

OnDeviceModel recommendedSpeechRecognition(int? ramMb) =>
    (ramMb ?? 4096) >= 3072
        ? speechRecognitionModels[1]
        : speechRecognitionModels[0];

/// How a model fits this phone, for the picker.
enum ModelFit { recommended, fits, tight }

ModelFit fitFor(OnDeviceModel model, int? ramMb, OnDeviceModel recommended) {
  if (model.id == recommended.id) return ModelFit.recommended;
  if (ramMb != null && ramMb < model.minRamMb) return ModelFit.tight;
  return ModelFit.fits;
}

String formatBytes(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / 1e9).toStringAsFixed(1)} GB';
  }
  return '${(bytes / 1e6).round()} MB';
}
