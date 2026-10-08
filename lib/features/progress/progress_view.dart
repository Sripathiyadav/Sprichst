import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models/learning_models.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/learning/achievements.dart';
import '../../domain/learning/exam_readiness.dart';
import '../../domain/learning/learner_insights.dart';
import '../../shared/widgets/app_widgets.dart';
import '../gamification/badge_icons.dart';

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    final weak = app.weakSkills;
    final next = app.currentLesson;
    return PageFrame(
      title: 'Your progress',
      subtitle:
          'These learning signals help Sprichst choose what to teach next. They are not CEFR certification.',
      child: ListView(padding: pageListPadding(context), children: [
        SoftCard(
          color: Theme.of(context).colorScheme.primary,
          child: Row(children: [
            CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                child: const Icon(Icons.workspace_premium)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${profile.currentLevel.label} learner',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary)),
                  Text(
                      '${profile.xp} XP · ${profile.completedLessonCount} lessons complete · ${profile.streakAt(DateTime.now())}-day streak',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ))
                ])),
          ]),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Skill matrix'),
        const SizedBox(height: 12),
        SoftCard(
            child: Column(children: [
          for (final skill in profile.scores.entries.entries) ...[
            SkillMeter(label: skill.key, value: skill.value),
            const SizedBox(height: 17)
          ]
        ])),
        const SizedBox(height: 24),
        const SectionTitle('How you learn'),
        const SizedBox(height: 12),
        for (final insight in app.insights) ...[
          _InsightCard(insight: insight),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (app.examReadiness != null) ...[
          const SizedBox(height: AppSpacing.md),
          SectionTitle('${profile.goal.label} readiness'),
          const SizedBox(height: 12),
          _ReadinessCard(readiness: app.examReadiness!, goal: profile.goal),
        ],
        const SizedBox(height: 24),
        const SectionTitle('Needs attention'),
        const SizedBox(height: 12),
        SoftCard(
          child: weak.isEmpty
              ? const Text(
                  'No weak spots yet. Keep completing lessons and Sprichst will flag the skills that need more practice.')
              : Column(children: [
                  for (final skill in weak) ...[
                    SkillMeter(
                      label: _weakSkillLabel(profile, skill),
                      value: profile.skillStats[skill]!.accuracy,
                    ),
                    const SizedBox(height: 17),
                  ],
                ]),
        ),
        const SizedBox(height: 24),
        SectionTitle(
          'Badges',
          action: Text(
              '${profile.gamification.badges.length} / ${Achievements.catalogue.length}'),
        ),
        const SizedBox(height: 12),
        _BadgeGrid(earned: profile.gamification.badges.keys.toSet()),
        const SizedBox(height: 24),
        const SectionTitle('Next milestone'),
        const SizedBox(height: 12),
        SoftCard(
          child: Text(next == null
              ? 'Your curriculum is loading.'
              : 'Next up: ${next.title}. ${next.objective}'),
        ),
      ]),
    );
  }

  static String _weakSkillLabel(LearningProfile profile, String skill) {
    final stat = profile.skillStats[skill]!;
    return '${skillLabel(skill)} · ${stat.correct}/${stat.attempts} correct';
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final LearnerInsight insight;

  static IconData _icon(InsightKind kind) => switch (kind) {
        InsightKind.productionGap => Icons.compare_arrows_rounded,
        InsightKind.weakestMode => Icons.track_changes_rounded,
        InsightKind.strength => Icons.thumb_up_alt_outlined,
        InsightKind.consistency => Icons.event_repeat_rounded,
        InsightKind.learning => Icons.insights_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon(insight.kind)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(insight.detail),
                if (insight.action != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(insight.action!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: context.accent)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness, required this.goal});

  final ExamReadiness readiness;
  final LearningGoal goal;

  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final pillar in readiness.pillars) ...[
              SkillMeter(
                label: '${pillar.module} · ${switch (pillar.status) {
                  ReadinessStatus.notStarted => 'not enough practice yet',
                  ReadinessStatus.building => 'building',
                  ReadinessStatus.onTrack => 'on track',
                }}',
                value: pillar.accuracy,
              ),
              const SizedBox(height: 14),
            ],
            Text(
              goal.exam == 'testdaf'
                  ? 'An estimate from your practice only. TestDaF reports levels (TDN 3–5) that depend on each test.'
                  : 'An estimate from your practice only. The Goethe-Zertifikat is passed module by module at 60%.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.earned});

  final Set<String> earned;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final badge in Achievements.catalogue)
            _BadgeTile(badge: badge, earned: earned.contains(badge.id)),
        ],
      );
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});

  final Achievement badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label:
          '${badge.title}. ${badge.description} ${earned ? 'Earned.' : 'Not earned yet.'}',
      excludeSemantics: true,
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: earned ? scheme.tertiary : context.softSurface,
              foregroundColor: earned ? scheme.onTertiary : scheme.outline,
              child: Icon(
                  earned ? badgeIcon(badge.icon) : Icons.lock_outline_rounded,
                  size: 28),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(badge.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: earned ? scheme.onSurface : scheme.onSurfaceVariant,
                )),
          ],
        ),
      ),
    );
  }
}
