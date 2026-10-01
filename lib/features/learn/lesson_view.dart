import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

class LessonView extends ConsumerStatefulWidget {
  const LessonView({super.key, required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends ConsumerState<LessonView> {
  var _stage = 0;
  var _exerciseIndex = 0;
  String? _selected;
  var _correctAnswers = 0;
  bool? _wasCorrect;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final stageCount = lesson.exercises.length + 2;
    return Scaffold(
      appBar: AppBar(
          title: Text(lesson.title), backgroundColor: SprichstTheme.cream),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                      value: (_stage + 1) / stageCount,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(99)),
                  const SizedBox(height: 26),
                  Expanded(
                      child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _content(context))),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _buttonEnabled ? () => _continue(context) : null,
                    child: Text(_buttonLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final lesson = widget.lesson;
    if (_stage == 0) {
      return SingleChildScrollView(
        key: const ValueKey('learn'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lesson.level.label,
              style: const TextStyle(
                  color: SprichstTheme.forest,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(lesson.title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 18),
          Text(lesson.introduction,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          ...lesson.examples.map((example) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoftCard(
                    child: Text(example,
                        style: Theme.of(context).textTheme.titleMedium)),
              )),
        ]),
      );
    }
    if (_stage <= lesson.exercises.length) {
      final exercise = lesson.exercises[_exerciseIndex];
      return Column(
          key: ValueKey(exercise.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRACTICE ${_exerciseIndex + 1}/${lesson.exercises.length}',
                style: const TextStyle(
                    color: SprichstTheme.forest,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
            const SizedBox(height: 16),
            Text(exercise.prompt,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            ...exercise.options.map((option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AnswerOption(
                    label: option,
                    selected: _selected == option,
                    correct:
                        _wasCorrect == null ? null : option == exercise.answer,
                    wrongSelection: _wasCorrect == false && _selected == option,
                    onTap: _wasCorrect == null
                        ? () => setState(() => _selected = option)
                        : null,
                  ),
                )),
            if (_wasCorrect != null) ...[
              const SizedBox(height: 14),
              SoftCard(
                color: _wasCorrect!
                    ? const Color(0xFFE2F3E6)
                    : const Color(0xFFFFE9E3),
                child: Text(exercise.explanation),
              ),
            ],
          ]);
    }
    return Center(
      key: const ValueKey('complete'),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircleAvatar(
            radius: 38,
            backgroundColor: SprichstTheme.forest,
            child: Icon(Icons.celebration, color: Colors.white, size: 38)),
        const SizedBox(height: 20),
        Text('Lesson complete!',
            style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
            'You got $_correctAnswers of ${lesson.exercises.length} correct and earned ${_correctAnswers * 10} XP.',
            textAlign: TextAlign.center),
      ]),
    );
  }

  bool get _buttonEnabled =>
      _stage == 0 ||
      _stage > widget.lesson.exercises.length ||
      _wasCorrect != null ||
      _selected != null;
  String get _buttonLabel {
    if (_stage == 0) return 'Start practice';
    if (_stage > widget.lesson.exercises.length) return 'Back to learning';
    if (_wasCorrect == null) return 'Check answer';
    return _exerciseIndex + 1 == widget.lesson.exercises.length
        ? 'Finish lesson'
        : 'Next question';
  }

  Future<void> _continue(BuildContext context) async {
    final lesson = widget.lesson;
    if (_stage == 0) return setState(() => _stage = 1);
    if (_stage > lesson.exercises.length) return Navigator.of(context).pop();
    if (_wasCorrect == null) {
      final correct = _selected == lesson.exercises[_exerciseIndex].answer;
      setState(() {
        _wasCorrect = correct;
        if (correct) _correctAnswers++;
      });
      return;
    }
    if (_exerciseIndex + 1 < lesson.exercises.length) {
      setState(() {
        _exerciseIndex++;
        _stage++;
        _selected = null;
        _wasCorrect = null;
      });
      return;
    }
    await ref
        .read(appControllerProvider)
        .completeLesson(lesson, correctAnswers: _correctAnswers);
    if (mounted) setState(() => _stage++);
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption(
      {required this.label,
      required this.selected,
      required this.correct,
      required this.wrongSelection,
      required this.onTap});
  final String label;
  final bool selected;
  final bool? correct;
  final bool wrongSelection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct == true
        ? const Color(0xFFE2F3E6)
        : wrongSelection
            ? const Color(0xFFFFE9E3)
            : selected
                ? SprichstTheme.sand
                : Colors.white;
    final border = correct == true
        ? SprichstTheme.forest
        : wrongSelection
            ? SprichstTheme.coral
            : selected
                ? SprichstTheme.forest
                : const Color(0xFFE4E8E2);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(16)),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
