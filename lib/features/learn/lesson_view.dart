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
  Widget build(BuildContext context) => GlassPage(
        appBar: AppBar(title: Text(widget.lesson.title)),
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
                              title: 'Lesson complete!',
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
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back to learning'),
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
  const _Introduction({super.key, required this.lesson, required this.onStart});

  final Lesson lesson;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lesson.level.label} · ${lesson.unit}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(lesson.title, style: theme.textTheme.displaySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(lesson.objective, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                Text(lesson.introduction, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xl),
                for (final example in lesson.examples)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: SoftCard(
                        child:
                            Text(example, style: theme.textTheme.titleMedium),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onStart, child: const Text('Start practice')),
      ],
    );
  }
}
