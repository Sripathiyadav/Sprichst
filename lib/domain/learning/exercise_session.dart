import 'dart:collection';

import '../models/learning_models.dart';
import 'exercise_evaluator.dart';

/// Walks a learner through a list of exercises: submit an answer, read the
/// feedback, advance. Pure Dart so the flow is testable without widgets.
///
/// With [retryMissed], an exercise answered wrongly is asked once more at the
/// end of the session, the way most language apps reinforce an error while it
/// is fresh. The retry is flagged on its result so it never counts twice.
class ExerciseSession {
  ExerciseSession(
    List<Exercise> exercises, {
    this.retryMissed = false,
    ExerciseEvaluator evaluator = const ExerciseEvaluator(),
  })  : _queue = [...exercises],
        _evaluator = evaluator;

  final bool retryMissed;
  final ExerciseEvaluator _evaluator;
  final List<Exercise> _queue;
  final List<ExerciseResult> _results = [];
  var _index = 0;
  var _retriesStarted = false;
  late final int _firstPassLength = _queue.length;

  /// Exercises still to ask plus those already asked, including any retries
  /// queued so far.
  int get total => _queue.length;
  int get position => _index;
  bool get isFinished => _index >= total;
  Exercise get current => _queue[_index];

  /// Whether [current] is a repeat of an exercise missed earlier.
  bool get isRetry => _index >= _firstPassLength;

  UnmodifiableListView<ExerciseResult> get results =>
      UnmodifiableListView(_results);

  /// Correct first attempts, the figure shown to the learner and recorded.
  int get correctCount =>
      _results.where((r) => r.isCorrect && !r.isRetry).length;

  int get firstAttemptCount => _results.where((r) => !r.isRetry).length;

  /// Feedback for [current], or null while it is still unanswered.
  ExerciseResult? get checked =>
      _results.length > _index ? _results.last : null;

  ExerciseResult submit(String response) {
    if (isFinished) throw StateError('The session is already finished.');
    if (checked != null) throw StateError('This exercise is already checked.');
    var result = _evaluator.evaluate(current, response);
    if (isRetry) result = result.asRetry();
    _results.add(result);
    if (retryMissed && !result.isCorrect && !isRetry) {
      _queue.add(current);
      _retriesStarted = true;
    }
    return result;
  }

  void advance() {
    if (checked == null) throw StateError('Check the answer before advancing.');
    _index++;
  }

  /// True once at least one miss has been queued for a retry.
  bool get hasRetries => _retriesStarted;
}
