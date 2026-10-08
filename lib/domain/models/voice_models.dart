/// The voice a new learner starts with. If the gateway does not have it
/// installed it falls back to the best voice it does have.
const defaultVoiceId = 'de_DE-thorsten-medium';

/// A comfortable starting speed for a learner: a little slower than natural.
const defaultSpeechRate = 170;
const minSpeechRate = 120;
const maxSpeechRate = 260;

/// How long you can pause before hands-free voice mode decides you are done.
const defaultVoicePauseMs = 1200;
const voicePauseChoices = <int, String>{
  800: 'Short',
  1200: 'Normal',
  1800: 'Long',
};

/// A text-to-speech voice the learner can choose.
class VoiceOption {
  const VoiceOption({
    required this.id,
    required this.label,
    required this.description,
    required this.engine,
    this.license = '',
    this.quality = '',
    this.available,
    this.installHint,
  });

  factory VoiceOption.fromJson(Map<String, dynamic> json) => VoiceOption(
        id: json['id'] as String,
        label: json['label'] as String? ?? json['id'] as String,
        description: json['description'] as String? ?? '',
        engine: json['engine'] as String? ?? 'piper',
        license: json['license'] as String? ?? '',
        quality: json['quality'] as String? ?? '',
        available: json['available'] as bool?,
        installHint: json['installHint'] as String?,
      );

  final String id;
  final String label;
  final String description;

  /// `piper` (open-source, offline neural voices) or `system`.
  final String engine;
  final String license;
  final String quality;

  /// Whether the gateway can use it right now; null when the gateway has not
  /// been asked (offline catalogue).
  final bool? available;
  final String? installHint;

  bool get isOpenSource => engine == 'piper';
}

/// The voices the gateway offers, with the one it would pick by default.
class VoiceList {
  const VoiceList({required this.voices, required this.defaultId});

  factory VoiceList.fromJson(Map<String, dynamic> json) => VoiceList(
        defaultId: json['default'] as String? ?? defaultVoiceId,
        voices: [
          for (final entry in json['voices'] as List<dynamic>? ?? const [])
            VoiceOption.fromJson(entry as Map<String, dynamic>),
        ],
      );

  /// What the app shows when the gateway cannot be reached: the open-source
  /// German voices it knows about, availability unknown.
  static const offline = VoiceList(defaultId: defaultVoiceId, voices: [
    VoiceOption(
      id: 'de_DE-thorsten-medium',
      label: 'Thorsten',
      description:
          'Clear, natural male voice. The best all-round open German voice.',
      engine: 'piper',
      license: 'CC0 (public domain)',
      quality: 'medium',
    ),
    VoiceOption(
      id: 'de_DE-thorsten-high',
      label: 'Thorsten (high quality)',
      description:
          'The same voice at higher fidelity. Larger and slower to generate.',
      engine: 'piper',
      license: 'CC0 (public domain)',
      quality: 'high',
    ),
    VoiceOption(
      id: 'de_DE-thorsten_emotional-medium',
      label: 'Thorsten (expressive)',
      description:
          'The same speaker with a livelier, more expressive delivery.',
      engine: 'piper',
      license: 'CC0 (public domain)',
      quality: 'medium',
    ),
    VoiceOption(
      id: 'de_DE-kerstin-low',
      label: 'Kerstin',
      description: 'Light, friendly voice. Small and fast.',
      engine: 'piper',
      license: 'CC0 (public domain)',
      quality: 'low',
    ),
    VoiceOption(
      id: 'de_DE-ramona-low',
      label: 'Ramona',
      description:
          'Calm, even voice for careful listening practice. Small and fast.',
      engine: 'piper',
      license: 'Open data (M-AILABS)',
      quality: 'low',
    ),
    VoiceOption(
      id: 'de_DE-karlsson-low',
      label: 'Karlsson',
      description: 'Steady voice with a measured pace. Small and fast.',
      engine: 'piper',
      license: 'Open data (M-AILABS)',
      quality: 'low',
    ),
    VoiceOption(
      id: 'de_DE-eva_k-x_low',
      label: 'Eva',
      description:
          'Very small model: runs anywhere, with a more synthetic sound.',
      engine: 'piper',
      license: 'Open data (M-AILABS)',
      quality: 'x_low',
    ),
  ]);

  final List<VoiceOption> voices;
  final String defaultId;

  /// The option for a stored voice id. Older profiles stored the system voice
  /// name ("Anna"), which maps to the matching system voice.
  VoiceOption? find(String id) {
    for (final voice in voices) {
      if (voice.id == id) return voice;
    }
    final legacy = id.toLowerCase();
    for (final voice in voices) {
      if (voice.engine == 'system' &&
          voice.label.toLowerCase().startsWith(legacy)) {
        return voice;
      }
    }
    return null;
  }

  /// A readable name for a stored voice id, even if the voice is unknown.
  String labelOf(String id) => find(id)?.label ?? id;
}

/// The result of asking the gateway to speak: the audio, and which voice made it.
class SpeechAudio {
  const SpeechAudio(this.bytes, {this.voiceUsed, this.usedFallback = false});

  final List<int> bytes;
  final String? voiceUsed;
  final bool usedFallback;
}
