import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/learning/exam_readiness.dart';
import '../../domain/learning/exercise_evaluator.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../flashcards/flashcard_session_view.dart';
import '../gamification/reward_news.dart';
import '../learn/exercises/exercise_runner.dart';

/// Modelltest: a short rehearsal of the exam the learner is preparing for, one
/// part per module, with a report by module at the end.
class MockExamView extends ConsumerStatefulWidget {
  const MockExamView({super.key, required this.exam});

  final MockExam exam;

  @override
  ConsumerState<MockExamView> createState() => _MockExamViewState();
}

enum _Stage { intro, exam, report }

class _MockExamViewState extends ConsumerState<MockExamView> {
  var _stage = _Stage.intro;
  ExamReport? _report;
  var _xp = 0;

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(appControllerProvider).profile!.goal;
    return GlassPage(
      appBar: AppBar(title: Text('${goal.label} mock exam')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Breakpoints.lessonMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AnimatedSwitcher(
                duration: motionDuration(context),
                child: switch (_stage) {
                  _Stage.intro => _Intro(
                      key: const ValueKey('intro'),
                      exam: widget.exam,
                      goal: goal,
                      onStart: () => setState(() => _stage = _Stage.exam),
                    ),
                  _Stage.exam => ExerciseRunner(
                      key: const ValueKey('exam'),
                      exercises: widget.exam.exercises,
                      finishLabel: 'See my results',
                      onFinished: _finish,
                    ),
                  _Stage.report => _Report(
                      key: const ValueKey('report'),
                      report: _report!,
                      xp: _xp,
                      goal: goal,
                    ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish(List<ExerciseResult> results) async {
    final app = ref.read(appControllerProvider);
    var xp = 0;
    try {
      xp = (await app.completePractice(results)).xpEarned;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('We could not save this exam. Your results are shown.'),
        ));
      }
    }
    if (!mounted) return;
    setState(() {
      _report = ExamReport.from(widget.exam, results);
      _xp = xp;
      _stage = _Stage.report;
    });
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    super.key,
    required this.exam,
    required this.goal,
    required this.onStart,
  });

  final MockExam exam;
  final LearningGoal goal;
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
                Text('Modelltest', style: theme.textTheme.displaySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A short rehearsal in the style of the ${goal.label}: '
                  '${exam.exercises.length} tasks across ${exam.sections.length} modules. '
                  'Take your time — nothing here is timed.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < exam.sections.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          leading: Icon(_icon(exam.sections[i].area)),
                          title: Text(exam.sections[i].module),
                          subtitle: Text(exam.sections[i].area.label),
                          trailing: Text(
                              '${exam.sections[i].exercises.length} tasks'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  goal.exam == 'testdaf'
                      ? 'TestDaF reports levels (TDN 3–5) that depend on each test, so treat this as a guide.'
                      : 'The Goethe-Zertifikat is passed module by module at 60%.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onStart, child: const Text('Begin')),
      ],
    );
  }

  static IconData _icon(SkillArea area) => switch (area) {
        SkillArea.reading => Icons.menu_book_rounded,
        SkillArea.listening => Icons.headphones_rounded,
        SkillArea.writing => Icons.edit_rounded,
        SkillArea.speaking => Icons.mic_rounded,
        _ => Icons.school_rounded,
      };
}

class _Report extends ConsumerWidget {
  const _Report({
    super.key,
    required this.report,
    required this.xp,
    required this.goal,
  });

  final ExamReport report;
  final int xp;
  final LearningGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reward = ref.read(appControllerProvider).lastReward;
    final passed = report.passedAll;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SessionSummaryBadge(
                  title: passed ? 'Bestanden!' : 'Noch nicht ganz',
                  line:
                      'Overall ${(report.overall * 100).round()}%${xp > 0 ? ' · +$xp XP' : ''}. '
                      '${passed ? 'Every module is at or above 60%.' : 'Modules under 60% need more practice.'}',
                ),
                const SizedBox(height: AppSpacing.lg),
                SoftCard(
                  child: Column(
                    children: [
                      for (final section in report.sections) ...[
                        SkillMeter(
                          label:
                              '${section.module} · ${section.passed ? 'passed' : 'keep practising'}',
                          value: section.score,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                if (goal.exam == 'testdaf')
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'A guide only: the real TestDaF reports TDN levels.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (reward != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  RewardNews(reward: reward),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Opens a mock exam, or says why there is none yet.
void openMockExam(BuildContext context, WidgetRef ref) {
  final exam = ref.read(appControllerProvider).buildMockExam();
  if (exam == null || exam.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('No exam tasks are available at your level yet.'),
    ));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => MockExamView(exam: exam),
  ));
}
