import 'dart:math' as math;

/// Compares what a speech recogniser heard with what the learner was meant to
/// say. Recognisers drop punctuation, vary capitalisation, and sometimes write
/// "ae" for "ä", so the comparison is forgiving of those and nothing else.
class SpeechMatcher {
  const SpeechMatcher();

  /// Similarity at or above this counts as a correct attempt.
  static const passMark = .8;

  /// 0 to 1: one minus the edit distance as a share of the longer text.
  double similarity(String heard, String target) {
    final a = normalise(heard);
    final b = normalise(target);
    if (a.isEmpty && b.isEmpty) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    return 1 - _editDistance(a, b) / math.max(a.length, b.length);
  }

  /// The best similarity against any of [targets].
  double bestSimilarity(String heard, Iterable<String> targets) =>
      targets.map((target) => similarity(heard, target)).fold(0.0, math.max);

  static String normalise(String text) => text
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Levenshtein distance in O(n·m) time and O(m) space.
  static int _editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      previous = current;
    }
    return previous[b.length];
  }
}
