import '../models/learning_models.dart';

class ExerciseResult {
  const ExerciseResult({
    required this.exercise,
    required this.response,
    required this.isCorrect,
    required this.feedback,
  });

  final Exercise exercise;
  final String response;
  final bool isCorrect;
  final String feedback;
}

/// Deterministic answer checking. No AI is involved: every current exercise
/// type has a closed set of accepted answers.
class ExerciseEvaluator {
  const ExerciseEvaluator();

  ExerciseResult evaluate(Exercise exercise, String response) {
    final given = _normalise(response);
    final accepted = [for (final a in exercise.acceptedAnswers) _normalise(a)];

    if (accepted.contains(given)) {
      return _result(exercise, response, true, exercise.explanation);
    }

    // German nouns are capitalised, so a case-only slip is a real mistake, but
    // one worth naming rather than showing as a mystery.
    final lowered = given.toLowerCase();
    final caseOnly = accepted.any((a) => a.toLowerCase() == lowered);
    final feedback = caseOnly
        ? 'Check your capitalisation — correct: ${exercise.answer}. ${exercise.explanation}'
        : 'Correct answer: ${exercise.answer}. ${exercise.explanation}';
    return _result(exercise, response, false, feedback);
  }

  ExerciseResult _result(
    Exercise exercise,
    String response,
    bool isCorrect,
    String feedback,
  ) =>
      ExerciseResult(
        exercise: exercise,
        response: response,
        isCorrect: isCorrect,
        feedback: feedback,
      );

  static final _whitespace = RegExp(r'\s+');
  static final _trailingPunctuation = RegExp(r'[.!?]+$');

  /// Collapses whitespace and ignores trailing sentence punctuation. Case and
  /// umlauts are preserved on purpose.
  static String _normalise(String text) => text
      .trim()
      .replaceAll(_whitespace, ' ')
      .replaceAll(_trailingPunctuation, '');
}
