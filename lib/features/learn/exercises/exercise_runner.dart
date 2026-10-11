import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/learning/exercise_evaluator.dart';
import '../../../domain/learning/exercise_session.dart';
import '../../../domain/models/learning_models.dart';
import '../../../shared/haptics.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'exam_inputs.dart';
import 'exercise_widgets.dart';

/// Runs a list of exercises: prompt, input, feedback, next. Shared by lessons
/// and targeted practice, which differ only in what happens afterwards.
class ExerciseRunner extends StatefulWidget {
  const ExerciseRunner({
    super.key,
    required this.exercises,
    required this.onFinished,
    this.finishLabel = 'Finish',
    this.retryMissed = false,
  });

  final List<Exercise> exercises;
  final String finishLabel;

  /// Ask each missed exercise once more at the end of the session.
  final bool retryMissed;

  /// Called once, after the last exercise has been checked and acknowledged.
  final Future<void> Function(List<ExerciseResult> results) onFinished;

  @override
  State<ExerciseRunner> createState() => _ExerciseRunnerState();
}

class _ExerciseRunnerState extends State<ExerciseRunner> {
  late final ExerciseSession _session = ExerciseSession(
    widget.exercises,
    retryMissed: widget.retryMissed,
  );
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
        Semantics(
          label: 'Progress',
          value: '${_session.position} of ${_session.total} questions',
          excludeSemantics: true,
          child: LinearProgressIndicator(
            value: _session.position / _session.total,
            minHeight: 10,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              key: ValueKey(exercise.id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _session.isRetry
                      ? 'Try again'
                      : 'Question ${_session.position + 1} of ${_session.total}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (exercise.examPart != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ExamPartTag(exercise.examPart!),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(exercise.prompt, style: theme.textTheme.headlineSmall),
                if (exercise.context != null &&
                    exercise.kind != ExerciseKind.cloze) ...[
                  const SizedBox(height: AppSpacing.md),
                  PassageCard(text: exercise.context!),
                ],
                const SizedBox(height: AppSpacing.xl),
                ExerciseRenderer(
                  exercise: exercise,
                  result: checked,
                  onResponse: (value) => setState(() => _response = value),
                  onSubmit:
                      _buttonEnabled && checked == null ? _onPressed : null,
                ),
                if (checked != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FeedbackBanner(
                    correct: checked.isCorrect,
                    message: checked.feedback,
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
      final result = _session.submit(_response!);
      result.isCorrect ? Haptics.success() : Haptics.mistake();
      setState(() {});
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
    this.leveledUpTo,
  });

  final String title;
  final int correct;
  final int total;
  final int xpEarned;
  final String? note;
  final CefrLevel? leveledUpTo;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            foregroundColor: Theme.of(context).colorScheme.onTertiary,
            child: const Icon(Icons.emoji_events, size: 38),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You got $correct of $total correct'
            '${xpEarned > 0 ? ' and earned $xpEarned XP' : ''}.',
            textAlign: TextAlign.center,
          ),
          if (leveledUpTo != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Level up! You are now working at ${leveledUpTo!.label}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note!, textAlign: TextAlign.center),
          ],
        ]),
      );
}
