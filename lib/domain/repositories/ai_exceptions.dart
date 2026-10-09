/// Why a cloud AI provider could not answer.
enum ProviderProblem {
  /// No API key has been saved.
  noKey,

  /// The provider rejected the key (revoked, mistyped, wrong account).
  invalidKey,

  /// The account's limit was reached; trying again later works.
  rateLimited,

  /// The device could not reach the provider.
  offline,

  /// The provider is having trouble or returned something unusable.
  unavailable,
}

/// A cloud AI provider (Groq, with the learner's own key) could not answer.
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

  /// Whether answering on the phone instead is a sensible offer: the problem
  /// is the provider's, not something the learner has to fix first.
  bool get canOfferPhone =>
      problem != ProviderProblem.noKey && problem != ProviderProblem.invalidKey;

  String get userMessage => switch (problem) {
        ProviderProblem.noKey =>
          'Add your free $provider key in Account → AI & voice to use $provider, or choose "This phone only".',
        ProviderProblem.invalidKey =>
          '$provider did not accept your key. Check it in Account → AI & voice, or create a new one.',
        ProviderProblem.rateLimited => retryAfter == null
            ? 'You have reached your $provider limit for now. It resets on its own; you can wait or answer on this phone.'
            : 'You have reached your $provider limit for now. Try again in ${_wait(retryAfter!)}, or answer on this phone.',
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

/// Speaking needs the phone's voices (or a developer server); a browser has
/// neither.
class VoiceUnavailableException implements Exception {
  const VoiceUnavailableException();

  @override
  String toString() =>
      'Spoken answers need the Sprichst phone app. You can still read every reply.';
}
