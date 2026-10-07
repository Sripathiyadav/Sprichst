import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/learning/exercise_evaluator.dart';
import '../../../domain/learning/exercise_session.dart';
import '../../../domain/models/learning_models.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'exercise_widgets.dart';

/// Runs a list of exercises: prompt, input, feedback, next. Shared by lessons
/// and targeted practice, which differ only in what happens afterwards.
class ExerciseRunner extends StatefulWidget {
  const ExerciseRunner({
    super.key,
    required this.exercises,
    required this.onFinished,
    this.finishLabel = 'Finish',
  });

  final List<Exercise> exercises;
  final String finishLabel;

  /// Called once, after the last exercise has been checked and acknowledged.
  final Future<void> Function(List<ExerciseResult> results) onFinished;

  @override
  State<ExerciseRunner> createState() => _ExerciseRunnerState();
}

class _ExerciseRunnerState extends State<ExerciseRunner> {
  late final ExerciseSession _session = ExerciseSession(widget.exercises);
  String? _response;
  var _finishing = false;

  @override
  Widget build(BuildContext context) {
    final exercise = _session.current;
    final checked = _session.checked;
    final isLast = _session.position + 1 == _session.total;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: _session.position / _session.total,
          minHeight: 7,
          borderRadius: BorderRadius.circular(99),
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              key: ValueKey(exercise.id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRACTICE ${_session.position + 1}/${_session.total}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(exercise.prompt, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xl),
                ExerciseRenderer(
                  exercise: exercise,
                  result: checked,
                  onResponse: (value) => setState(() => _response = value),
                ),
                if (checked != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  SoftCard(
                    color: checked.isCorrect
                        ? context.successSurface
                        : context.dangerSurface,
                    child: Text(checked.feedback),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _buttonEnabled ? _onPressed : null,
          child: Text(
            checked == null
                ? 'Check answer'
                : isLast
                    ? widget.finishLabel
                    : 'Next question',
          ),
        ),
      ],
    );
  }

  bool get _buttonEnabled =>
      !_finishing && (_session.checked != null || _response != null);

  Future<void> _onPressed() async {
    if (_session.checked == null) {
      setState(() => _session.submit(_response!));
      return;
    }
    if (_session.position + 1 < _session.total) {
      setState(() {
        _session.advance();
        _response = null;
      });
      return;
    }
    setState(() => _finishing = true);
    try {
      await widget.onFinished(_session.results);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }
}

/// The closing card shown after a lesson or practice session.
class SessionSummary extends StatelessWidget {
  const SessionSummary({
    super.key,
    required this.title,
    required this.correct,
    required this.total,
    required this.xpEarned,
    this.note,
  });

  final String title;
  final int correct;
  final int total;
  final int xpEarned;
  final String? note;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.celebration, size: 38),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You got $correct of $total correct'
            '${xpEarned > 0 ? ' and earned $xpEarned XP' : ''}.',
            textAlign: TextAlign.center,
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note!, textAlign: TextAlign.center),
          ],
        ]),
      );
}
