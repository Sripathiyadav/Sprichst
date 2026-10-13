/// Why a cloud AI provider could not answer.
enum ProviderProblem {
  /// No API key has been saved.
  noKey,

  /// The provider rejected the key (revoked, mistyped, wrong account).
  invalidKey,

  /// The account's limit was reached; trying again later works.
  rateLimited,

  /// The account has no credit left (a paid provider); waiting will not help.
  noCredit,

  /// The provider does not offer the chosen model (renamed or retired).
  unknownModel,

  /// The device could not reach the provider.
  offline,

  /// The provider is having trouble or returned something unusable.
  unavailable,
}

/// A cloud AI provider (Groq, Gemini, OpenAI…, with the learner's own key)
/// could not answer.
///
/// The app never answers from somewhere else instead without asking: text
/// leaving the device, or staying on it, is the learner's choice. The message
/// says what happened and what the learner can do.
class ProviderUnavailableException implements Exception {
  const ProviderUnavailableException(
    this.provider,
    this.problem, {
    this.retryAfter,
  });

  final String provider;
  final ProviderProblem problem;

  /// How long the provider asked us to wait, when it said.
  final Duration? retryAfter;

  /// Set once at start-up (true in a web browser). A browser has no on-device
  /// models, so advice to "answer on this phone" would send the learner
  /// nowhere: messages leave it out and say a key is needed.
  static bool inBrowser = false;

  /// Whether answering on the phone instead is a sensible offer: the problem
  /// is the provider's, not something the learner has to fix first.
  bool get canOfferPhone =>
      !inBrowser &&
      problem != ProviderProblem.noKey &&
      problem != ProviderProblem.invalidKey &&
      problem != ProviderProblem.unknownModel;

  String get userMessage => inBrowser ? _browserMessage : _phoneMessage;

  String get _browserMessage => switch (problem) {
        ProviderProblem.noKey =>
          'Add your $provider key in Account → AI & voice. A web browser cannot run AI models itself, so a key is needed here.',
        ProviderProblem.invalidKey =>
          '$provider did not accept your key. Check it in Account → AI & voice, or create a new one.',
        ProviderProblem.rateLimited => retryAfter == null
            ? 'You have reached your $provider limit for now. It resets on its own; try again later.'
            : 'You have reached your $provider limit for now. Try again in ${_wait(retryAfter!)}.',
        ProviderProblem.noCredit =>
          'Your $provider account has no credit left. Add credit with $provider, or choose another provider in Account → AI & voice.',
        ProviderProblem.unknownModel =>
          '$provider does not offer the model you chose. Pick another one in Account → AI & voice.',
        ProviderProblem.offline =>
          'Could not reach $provider. Check your internet connection and try again.',
        ProviderProblem.unavailable =>
          '$provider is not answering right now. Try again in a moment.',
      };

  String get _phoneMessage => switch (problem) {
        ProviderProblem.noKey =>
          'Add your $provider key in Account → AI & voice to use $provider, or choose "This phone only".',
        ProviderProblem.invalidKey =>
          '$provider did not accept your key. Check it in Account → AI & voice, or create a new one.',
        ProviderProblem.rateLimited => retryAfter == null
            ? 'You have reached your $provider limit for now. It resets on its own; you can wait or answer on this phone.'
            : 'You have reached your $provider limit for now. Try again in ${_wait(retryAfter!)}, or answer on this phone.',
        ProviderProblem.noCredit =>
          'Your $provider account has no credit left. Add credit with $provider, choose another provider in Account → AI & voice, or answer on this phone.',
        ProviderProblem.unknownModel =>
          '$provider does not offer the model you chose. Pick another one in Account → AI & voice.',
        ProviderProblem.offline =>
          'Could not reach $provider. Check your internet connection, or answer on this phone.',
        ProviderProblem.unavailable =>
          '$provider is not answering right now. Try again in a moment, or answer on this phone.',
      };

  static String _wait(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return '${d.inSeconds.clamp(1, 59)} s';
  }

  @override
  String toString() => userMessage;
}

/// "This phone only" was chosen in a web browser, which cannot run models.
/// Nothing is sent anywhere instead: the learner decides what to do.
class LocalModelsUnavailableException implements Exception {
  const LocalModelsUnavailableException();

  @override
  String toString() =>
      '"This phone only" cannot work in a web browser, because models cannot run here. Choose "My own AI key" in Account → AI & voice and add a key, or use the phone app.';
}

/// The learner's provider has no speech recognition, and this device cannot
/// run Whisper itself (a browser).
class HearingUnavailableException implements Exception {
  const HearingUnavailableException(this.provider);

  final String provider;

  @override
  String toString() =>
      '$provider cannot listen to recordings. Type your message, choose Groq or OpenAI in Account → AI & voice, or use the Sprichst phone app.';
}

/// Speaking needs the phone's voices (or a developer server); a browser has
/// neither.
class VoiceUnavailableException implements Exception {
  const VoiceUnavailableException();

  @override
  String toString() =>
      'Spoken answers need the Sprichst phone app. You can still read every reply.';
}
