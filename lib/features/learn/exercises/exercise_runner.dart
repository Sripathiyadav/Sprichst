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
        const SizedBox(height: AppSpacing.md),
        SkillMeter(
          label: _session.isRetry
              ? 'Try again'
              : 'Exercise ${_session.position + 1} of ${_session.total}',
          value: _session.position / _session.total,
          valueLabel: ' ',
          compact: true,
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              key: ValueKey(exercise.id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_instruction(exercise.kind),
                    style: theme.textTheme.labelSmall),
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
                  FeedbackBanner.answer(
                    correct: checked.isCorrect,
                    message: checked.feedback,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          onPressed: _buttonEnabled ? _onPressed : null,
          block: true,
          label: checked == null
              ? 'Check answer'
              : isLast
                  ? widget.finishLabel
                  : 'Continue',
        ),
      ],
    );
  }

  /// The instruction above the prompt, in capitals.
  static String _instruction(ExerciseKind kind) => switch (kind) {
        ExerciseKind.multipleChoice => 'CHOOSE THE ANSWER',
        ExerciseKind.cloze => 'FILL IN THE GAPS',
        ExerciseKind.listening => 'LISTEN, THEN ANSWER',
        ExerciseKind.writing => 'WRITE YOUR ANSWER',
        ExerciseKind.speaking => 'SAY IT ALOUD',
        _ => 'ANSWER',
      };

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

/// The closing screen after a lesson or practice session: the score as the one
/// big number, and what it earned.
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.zero,
              child: EditorialNumber(
                value: correct,
                label: 'Correct',
                unit: 'of $total',
                disc: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.displaySmall),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You got $correct of $total correct'
              '${xpEarned > 0 ? ' and earned $xpEarned XP' : ''}.',
              style: theme.textTheme.bodyLarge?.copyWith(color: t.inkMuted),
            ),
            if (leveledUpTo != null) ...[
              const SizedBox(height: AppSpacing.md),
              FeedbackBanner(
                tone: BannerTone.success,
                title: 'New level',
                message: 'You are now working at ${leveledUpTo!.label}.',
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(note!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
