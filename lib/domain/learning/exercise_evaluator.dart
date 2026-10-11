import '../models/learning_models.dart';
import 'speech_matcher.dart';
import 'writing_assessor.dart';

class ExerciseResult {
  const ExerciseResult({
    required this.exercise,
    required this.response,
    required this.isCorrect,
    required this.feedback,
    this.isRetry = false,
    double? score,
  }) : score = score ?? (isCorrect ? 1.0 : 0.0);

  final Exercise exercise;
  final String response;
  final bool isCorrect;
  final String feedback;

  /// Credit from 0 to 1. Whole-answer exercises are 0 or 1; cloze passages and
  /// writing give partial credit, which exam practice reports per skill.
  final double score;

  /// True for the second attempt at an exercise missed earlier in the same
  /// session. Retries help learning but never count toward statistics or XP.
  final bool isRetry;

  ExerciseResult asRetry() => ExerciseResult(
        exercise: exercise,
        response: response,
        isCorrect: isCorrect,
        feedback: feedback,
        isRetry: true,
        score: score,
      );
}

/// Deterministic answer checking. No AI is involved: every current exercise
/// type has a closed set of accepted answers.
class ExerciseEvaluator {
  const ExerciseEvaluator({
    this.writing = const WritingAssessor(),
    this.speech = const SpeechMatcher(),
  });

  final WritingAssessor writing;
  final SpeechMatcher speech;

  /// Separates a cloze answer's gaps, in the order the gaps appear.
  static const gapSeparator = '|';

  ExerciseResult evaluate(Exercise exercise, String response) =>
      switch (exercise.kind) {
        ExerciseKind.cloze => _cloze(exercise, response),
        ExerciseKind.writing => _writing(exercise, response),
        ExerciseKind.speaking => _speaking(exercise, response),
        _ => _exact(exercise, response),
      };

  ExerciseResult _exact(Exercise exercise, String response) {
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

  ExerciseResult _cloze(Exercise exercise, String response) {
    final given = response.split(gapSeparator);
    var correct = 0;
    final misses = <String>[];
    for (var i = 0; i < exercise.gaps.length; i++) {
      final expected = exercise.gaps[i].answer;
      final chosen = i < given.length ? given[i].trim() : '';
      if (chosen == expected) {
        correct++;
      } else {
        misses.add('(${i + 1}) $expected');
      }
    }
    final total = exercise.gaps.length;
    final allCorrect = correct == total;
    return ExerciseResult(
      exercise: exercise,
      response: response,
      isCorrect: allCorrect,
      score: correct / total,
      feedback: allCorrect
          ? exercise.explanation
          : '$correct of $total gaps correct. Answers: ${misses.join(', ')}. '
              '${exercise.explanation}',
    );
  }

  ExerciseResult _writing(Exercise exercise, String response) {
    final brief = exercise.brief!;
    final assessment = writing.assess(response, brief);
    final passed = assessment.score >= WritingAssessor.passMark;
    final percent = (assessment.score * 100).round();
    final covered = assessment.pointsCovered.where((c) => c).length;
    final summary = '$percent% · $covered of ${brief.points.length} content '
        'points · ${assessment.wordCount} words.';
    return ExerciseResult(
      exercise: exercise,
      response: response,
      isCorrect: passed,
      score: assessment.score,
      feedback: [
        summary,
        if (assessment.notes.isNotEmpty) assessment.notes.join(' '),
        if (passed) exercise.explanation,
        if (!passed) 'Model answer: ${exercise.answer}',
      ].join(' '),
    );
  }

  ExerciseResult _speaking(Exercise exercise, String response) {
    final similarity =
        speech.bestSimilarity(response, exercise.acceptedAnswers);
    final passed = similarity >= SpeechMatcher.passMark;
    return ExerciseResult(
      exercise: exercise,
      response: response,
      isCorrect: passed,
      score: similarity,
      feedback: passed
          ? exercise.explanation
          : 'I heard: "$response". Target: ${exercise.answer}. '
              '${exercise.explanation}',
    );
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
