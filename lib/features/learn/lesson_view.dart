import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/learning/exercise_evaluator.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'exercises/exercise_runner.dart';

enum _Stage { introduction, practice, complete }

class LessonView extends ConsumerStatefulWidget {
  const LessonView({super.key, required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends ConsumerState<LessonView> {
  var _stage = _Stage.introduction;
  List<ExerciseResult> _results = const [];
  var _outcome = (xpEarned: 0, leveledUpTo: null as CefrLevel?);
  var _wasCompletedBefore = false;

  @override
  Widget build(BuildContext context) {
    final lessons = ref.watch(appControllerProvider).curriculum.lessons;
    final index = lessons.indexWhere((l) => l.id == widget.lesson.id);
    final number = (index < 0 ? 1 : index + 1).toString().padLeft(2, '0');
    final lesson = widget.lesson;
    return GlassPage(
      appBar: MastheadBar(
        eyebrow: 'LESSON $number · ${lesson.level.label} · ${lesson.unit}',
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Breakpoints.lessonMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AnimatedSwitcher(
                duration: motionDuration(context),
                child: switch (_stage) {
                  _Stage.introduction => _Introduction(
                      key: const ValueKey('introduction'),
                      lesson: widget.lesson,
                      number: int.parse(number),
                      onStart: _startPractice,
                    ),
                  _Stage.practice => ExerciseRunner(
                      key: const ValueKey('practice'),
                      exercises: widget.lesson.exercises,
                      finishLabel: 'Finish lesson',
                      retryMissed: true,
                      onFinished: _finish,
                    ),
                  _Stage.complete => Column(
                      key: const ValueKey('complete'),
                      children: [
                        Expanded(
                          child: SessionSummary(
                            title: 'Lesson complete',
                            correct: _results
                                .where((r) => r.isCorrect && !r.isRetry)
                                .length,
                            total: _results.where((r) => !r.isRetry).length,
                            xpEarned: _outcome.xpEarned,
                            leveledUpTo: _outcome.leveledUpTo,
                            note: _wasCompletedBefore
                                ? 'XP is awarded the first time you complete a lesson.'
                                : null,
                          ),
                        ),
                        PrimaryButton(
                          label: 'Back to learning',
                          block: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startPractice() {
    final controller = ref.read(appControllerProvider);
    _wasCompletedBefore =
        controller.profile?.isLessonCompleted(widget.lesson.id) ?? false;
    controller.startLesson(widget.lesson);
    setState(() => _stage = _Stage.practice);
  }

  Future<void> _finish(List<ExerciseResult> results) async {
    try {
      final outcome = await ref
          .read(appControllerProvider)
          .completeLesson(widget.lesson, results);
      if (!mounted) return;
      setState(() {
        _results = results;
        _outcome = outcome;
        _stage = _Stage.complete;
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

class _Introduction extends StatelessWidget {
  const _Introduction({
    super.key,
    required this.lesson,
    required this.number,
    required this.onStart,
  });

  final Lesson lesson;
  final int number;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: EdgeInsets.zero,
                  child: EditorialNumber(
                    value: number,
                    label: 'Lesson',
                    caption: '${lesson.durationMinutes} min',
                    disc: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child:
                      Text(lesson.title, style: theme.textTheme.displaySmall),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(lesson.objective,
                    style:
                        theme.textTheme.bodyLarge?.copyWith(color: t.inkMuted)),
                const SizedBox(height: AppSpacing.xl),
                FeaturePanel(
                  title: 'Introduction',
                  hatch: false,
                  children: [
                    Text(lesson.introduction,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: t.onPanel)),
                  ],
                ),
                if (lesson.examples.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle('Examples'),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final example in lesson.examples)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: SoftCard(
                        child:
                            Text(example, style: theme.textTheme.headlineSmall),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(label: 'Start practice', block: true, onPressed: onStart),
      ],
    );
  }
}
