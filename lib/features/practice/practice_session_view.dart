import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/learning/exercise_evaluator.dart';
import '../../domain/models/learning_models.dart';
import '../learn/exercises/exercise_runner.dart';

/// A short, targeted practice round over exercises from any lesson.
class PracticeSessionView extends ConsumerStatefulWidget {
  const PracticeSessionView({
    super.key,
    required this.title,
    required this.exercises,
  });

  final String title;
  final List<Exercise> exercises;

  @override
  ConsumerState<PracticeSessionView> createState() =>
      _PracticeSessionViewState();
}

class _PracticeSessionViewState extends ConsumerState<PracticeSessionView> {
  List<ExerciseResult>? _results;
  var _xpEarned = 0;

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Breakpoints.lessonMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: results == null
                  ? ExerciseRunner(
                      exercises: widget.exercises,
                      finishLabel: 'Finish practice',
                      onFinished: _finish,
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: SessionSummary(
                            title: 'Nice work!',
                            correct: results.where((r) => r.isCorrect).length,
                            total: results.length,
                            xpEarned: _xpEarned,
                          ),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish(List<ExerciseResult> results) async {
    try {
      final xp =
          await ref.read(appControllerProvider).completePractice(results);
      if (!mounted) return;
      setState(() {
        _results = results;
        _xpEarned = xp;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not save your progress. Please try again.'),
        ),
      );
    }
  }
}

/// Opens a practice round for [skillIds] (or the learner's weak skills when
/// null), or explains why none is available yet.
void openPractice(
  BuildContext context,
  WidgetRef ref, {
  Iterable<String>? skillIds,
  String title = 'Practice',
}) {
  final exercises =
      ref.read(appControllerProvider).practiceExercises(skillIds: skillIds);
  if (exercises.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Complete a lesson first — practice is built from what you have missed.',
        ),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PracticeSessionView(title: title, exercises: exercises),
    ),
  );
}
