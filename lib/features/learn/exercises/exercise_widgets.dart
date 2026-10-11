import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/learning/exercise_evaluator.dart';
import '../../../domain/models/learning_models.dart';
import '../../../shared/haptics.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'exam_inputs.dart';

/// Renders the input for an [Exercise] and reports what the learner entered.
///
/// [onResponse] receives the answer text, or null while the input is not yet
/// complete (so the caller can keep "Check" disabled). Once [result] is set the
/// input is locked and shows the outcome. Give each exercise a distinct key so
/// local input state resets between questions.
class ExerciseRenderer extends StatelessWidget {
  const ExerciseRenderer({
    super.key,
    required this.exercise,
    required this.onResponse,
    this.onSubmit,
    this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;

  /// Called when the learner presses Enter / Done in a typed answer.
  final VoidCallback? onSubmit;
  final ExerciseResult? result;

  @override
  Widget build(BuildContext context) => switch (exercise.kind) {
        ExerciseKind.multipleChoice => MultipleChoiceInput(
            exercise: exercise,
            onResponse: onResponse,
            result: result,
          ),
        ExerciseKind.fillBlank || ExerciseKind.translation => _TypedInput(
            exercise: exercise,
            onResponse: onResponse,
            onSubmit: onSubmit,
            result: result,
          ),
        ExerciseKind.cloze => ClozeInput(
            exercise: exercise,
            onResponse: onResponse,
            result: result,
          ),
        ExerciseKind.listening => ListeningInput(
            exercise: exercise,
            onResponse: onResponse,
            result: result,
          ),
        ExerciseKind.writing => WritingInput(
            exercise: exercise,
            onResponse: onResponse,
            result: result,
          ),
        ExerciseKind.speaking => SpeakingInput(
            exercise: exercise,
            onResponse: onResponse,
            result: result,
          ),
        ExerciseKind.wordOrder => _WordOrderInput(
            exercise: exercise,
            onResponse: onResponse,
            result: result,
          ),
      };
}

class MultipleChoiceInput extends StatefulWidget {
  const MultipleChoiceInput({
    super.key,
    required this.exercise,
    required this.onResponse,
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final ExerciseResult? result;

  @override
  State<MultipleChoiceInput> createState() => MultipleChoiceInputState();
}

class MultipleChoiceInputState extends State<MultipleChoiceInput> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final locked = widget.result != null;
    final accepted = widget.exercise.acceptedAnswers;
    return Column(
      children: [
        for (final (index, option) in widget.exercise.options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OptionTile(
              label: option,
              marker: String.fromCharCode(0x41 + index),
              locale: const Locale('de'),
              state: locked && accepted.contains(option)
                  ? OptionState.correct
                  : locked && _selected == option
                      ? OptionState.incorrect
                      : _selected == option
                          ? OptionState.selected
                          : OptionState.idle,
              onTap: locked
                  ? null
                  : () {
                      Haptics.selection();
                      setState(() => _selected = option);
                      widget.onResponse(option);
                    },
            ),
          ),
      ],
    );
  }
}

class _TypedInput extends StatefulWidget {
  const _TypedInput({
    required this.exercise,
    required this.onResponse,
    required this.onSubmit,
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final VoidCallback? onSubmit;
  final ExerciseResult? result;

  @override
  State<_TypedInput> createState() => _TypedInputState();
}

class _TypedInputState extends State<_TypedInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final t = context.tokens;
    final color = result == null
        ? null
        : result.isCorrect
            ? t.success
            : t.danger;
    return TextField(
      controller: _controller,
      autofocus: true,
      readOnly: result != null,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      style: Theme.of(context).textTheme.bodyLarge,
      onSubmitted: (_) => widget.onSubmit?.call(),
      decoration: InputDecoration(
        labelText: 'Your answer',
        // The icon, not just the border colour, tells the outcome.
        suffixIcon: result == null
            ? null
            : Icon(result.isCorrect ? Icons.check_circle : Icons.cancel,
                color: color),
        enabledBorder: result == null
            ? null
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(
                  color: result.isCorrect ? t.success : t.danger,
                  width: 2.5,
                ),
              ),
      ),
      onChanged: (value) =>
          widget.onResponse(value.trim().isEmpty ? null : value),
    );
  }
}

class _WordOrderInput extends StatefulWidget {
  const _WordOrderInput({
    required this.exercise,
    required this.onResponse,
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final ExerciseResult? result;

  @override
  State<_WordOrderInput> createState() => _WordOrderInputState();
}

class _WordOrderInputState extends State<_WordOrderInput> {
  /// Indices into `exercise.options`, in the order the learner placed them.
  /// Indices (not words) keep repeated words distinct.
  final _placed = <int>[];

  void _place(int index) {
    setState(() => _placed.add(index));
    _report();
  }

  void _remove(int index) {
    setState(() => _placed.remove(index));
    _report();
  }

  void _report() {
    final words = widget.exercise.options;
    widget.onResponse(_placed.length == words.length
        ? _placed.map((i) => words[i]).join(' ')
        : null);
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.exercise.options;
    final locked = widget.result != null;
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: t.lineStrong, width: 1.5),
          ),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final index in _placed)
                InputChip(
                  label: Text(words[index]),
                  onPressed: locked ? null : () => _remove(index),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var index = 0; index < words.length; index++)
              ActionChip(
                label: Text(words[index]),
                onPressed: locked || _placed.contains(index)
                    ? null
                    : () => _place(index),
              ),
          ],
        ),
      ],
    );
  }
}
