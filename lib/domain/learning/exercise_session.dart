import 'dart:collection';

import '../models/learning_models.dart';
import 'exercise_evaluator.dart';

/// Walks a learner through a fixed list of exercises: submit an answer, read
/// the feedback, advance. Pure Dart so the flow is testable without widgets.
class ExerciseSession {
  ExerciseSession(
    List<Exercise> exercises, {
    ExerciseEvaluator evaluator = const ExerciseEvaluator(),
  })  : exercises = List.unmodifiable(exercises),
        _evaluator = evaluator;

  final List<Exercise> exercises;
  final ExerciseEvaluator _evaluator;
  final List<ExerciseResult> _results = [];
  var _index = 0;

  int get total => exercises.length;
  int get position => _index;
  bool get isFinished => _index >= total;
  Exercise get current => exercises[_index];

  UnmodifiableListView<ExerciseResult> get results =>
      UnmodifiableListView(_results);
  int get correctCount => _results.where((r) => r.isCorrect).length;

  /// Feedback for [current], or null while it is still unanswered.
  ExerciseResult? get checked =>
      _results.length > _index ? _results.last : null;

  ExerciseResult submit(String response) {
    if (isFinished) throw StateError('The session is already finished.');
    if (checked != null) throw StateError('This exercise is already checked.');
    final result = _evaluator.evaluate(current, response);
    _results.add(result);
    return result;
  }

  void advance() {
    if (checked == null) throw StateError('Check the answer before advancing.');
    _index++;
  }
}
