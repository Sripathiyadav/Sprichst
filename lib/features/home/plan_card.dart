import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/learning/adaptive_planner.dart';
import '../../shared/widgets/app_widgets.dart';
import '../learn/lesson_view.dart';
import '../practice/practice_session_view.dart';

/// The one thing the learner should do next, and why. The strongest colour on
/// the screen (black in light mode, gold in dark mode) goes here on purpose:
/// one clear primary action per screen.
class PlanCard extends ConsumerWidget {
  const PlanCard({super.key, required this.plan});

  final DailyPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlagStripe(outline: scheme.onPrimary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your plan for today',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: scheme.onPrimary.withValues(alpha: .85)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(plan.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: scheme.onPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(plan.reason,
              style:
                  theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimary)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onPrimary,
              foregroundColor: scheme.primary,
            ),
            onPressed: () => startPlan(context, ref, plan),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(switch (plan.kind) {
              PlanKind.lesson => 'Open lesson',
              PlanKind.review => 'Start review',
              PlanKind.practice => 'Start practice',
            }),
          ),
        ],
      ),
    );
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
