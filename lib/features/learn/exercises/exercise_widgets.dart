import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/learning/exercise_evaluator.dart';
import '../../../domain/models/learning_models.dart';

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
    this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final ExerciseResult? result;

  @override
  Widget build(BuildContext context) => switch (exercise.kind) {
        ExerciseKind.multipleChoice => _MultipleChoiceInput(
            exercise: exercise,
            onResponse: onResponse,
            result: result,
          ),
        ExerciseKind.fillBlank || ExerciseKind.translation => _TypedInput(
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

class _MultipleChoiceInput extends StatefulWidget {
  const _MultipleChoiceInput({
    required this.exercise,
    required this.onResponse,
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final ExerciseResult? result;

  @override
  State<_MultipleChoiceInput> createState() => _MultipleChoiceInputState();
}

class _MultipleChoiceInputState extends State<_MultipleChoiceInput> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final locked = widget.result != null;
    final accepted = widget.exercise.acceptedAnswers;
    return Column(
      children: [
        for (final option in widget.exercise.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _OptionTile(
              label: option,
              selected: _selected == option,
              isAnswer: locked && accepted.contains(option),
              isWrongPick:
                  locked && _selected == option && !accepted.contains(option),
              onTap: locked
                  ? null
                  : () {
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
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
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
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      readOnly: result != null,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Your answer',
        enabledBorder: result == null
            ? null
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(
                  color: result.isCorrect ? scheme.primary : scheme.error,
                  width: 2,
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: scheme.outlineVariant),
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.isAnswer,
    required this.isWrongPick,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isAnswer;
  final bool isWrongPick;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = isAnswer
        ? context.successSurface
        : isWrongPick
            ? context.dangerSurface
            : selected
                ? context.softSurface
                : scheme.surface;
    final border = isAnswer || (selected && !isWrongPick)
        ? scheme.primary
        : isWrongPick
            ? scheme.error
            : scheme.outlineVariant;
    final radius = BorderRadius.circular(AppRadius.input);
    return Material(
      color: fill,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: radius,
          ),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
