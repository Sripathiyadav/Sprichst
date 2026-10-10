import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/learning/adaptive_planner.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../learn/lesson_view.dart';
import '../practice/practice_session_view.dart';

/// The one thing the learner should do next, and why: the screen's single
/// feature panel. The action is a labelled coral arrow.
class PlanCard extends ConsumerWidget {
  const PlanCard({super.key, required this.plan});

  final DailyPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final lesson = plan.lesson;
    final eyebrow = switch (plan.kind) {
      PlanKind.lesson when lesson != null =>
        'Lesson ${_number(app, lesson.id)} · ${lesson.level.label} · ${lesson.unit}',
      PlanKind.review => 'Review',
      _ => 'Practice',
    };
    return FeaturePanel(
      eyebrow: eyebrow,
      title: plan.title,
      meta: lesson == null ? null : '${lesson.durationMinutes} min',
      actionLabel: switch (plan.kind) {
        PlanKind.lesson => 'Open lesson',
        PlanKind.review => 'Start review',
        PlanKind.practice => 'Start practice',
      },
      onAction: () => startPlan(context, ref, plan),
      children: [Text(plan.reason)],
    );
  }

  /// "08": the lesson's place in the course.
  static String _number(AppController app, String lessonId) {
    final index = app.curriculum.lessons.indexWhere((l) => l.id == lessonId);
    return (index < 0 ? 1 : index + 1).toString().padLeft(2, '0');
  }
}

/// Opens whatever [plan] recommends.
void startPlan(BuildContext context, WidgetRef ref, DailyPlan plan) {
  switch (plan.kind) {
    case PlanKind.lesson:
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LessonView(lesson: plan.lesson!),
      ));
    case PlanKind.review:
      openPractice(context, ref, title: 'Review');
    case PlanKind.practice:
      openPractice(
        context,
        ref,
        skillIds: plan.skillIds,
        title: 'Weak-skill practice',
      );
  }
}
