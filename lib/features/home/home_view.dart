import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/learning/adaptive_planner.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../learn/lesson_view.dart';
import '../practice/practice_session_view.dart';
import '../gamification/quests_card.dart';
import 'plan_card.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    final plan = app.plan;
    final lesson = app.currentLesson;
    final weak = app.weakSkills;

    return PageFrame(
      title: '${_greeting(DateTime.now().hour)}, ${profile.name}',
      subtitle: lesson == null
          ? profile.currentLevel.label
          : '${profile.currentLevel.label} · ${lesson.unit}',
      trailing: ProfileAvatar(name: profile.name),
      child: ListView(
        padding: pageListPadding(context),
        children: [
          if (plan != null) PlanCard(plan: plan),
          if (plan != null &&
              plan.kind != PlanKind.lesson &&
              lesson != null) ...[
            const SizedBox(height: AppSpacing.md),
            _NextLessonCard(lesson: lesson),
          ],
          const SizedBox(height: AppSpacing.md),
          QuestsCard(profile: profile, now: DateTime.now()),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Your progress'),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns whenever they fit, including on phones; one column
              // when the width is tight or text is enlarged.
              final enlarged = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              final twoColumns =
                  constraints.maxWidth >= Breakpoints.twoStatTiles && !enlarged;
              final width = twoColumns
                  ? (constraints.maxWidth - AppSpacing.sm) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tile in [
                    StatTile(
                      icon: Icons.local_fire_department_outlined,
                      value: '${profile.streakAt(DateTime.now())}',
                      label: 'day streak',
                    ),
                    StatTile(
                      icon: Icons.bolt_outlined,
                      value: '${profile.xp}',
                      label: 'XP earned',
                    ),
                    StatTile(
                      icon: Icons.refresh,
                      value: '${app.dueReviews}',
                      label: 'reviews due',
                    ),
                    StatTile(
                      icon: Icons.auto_fix_high_outlined,
                      value: '${app.pendingMistakes}',
                      label: 'mistakes to fix',
                    ),
                  ])
                    SizedBox(width: width, child: tile),
                ],
              );
            },
          ),
          if (weak.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionTitle('Needs practice'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final skill in weak)
                  ActionChip(
                    label: Text(skillLabel(skill)),
                    avatar: const Icon(Icons.bolt, size: 18),
                    onPressed: () => openPractice(
                      context,
                      ref,
                      skillIds: [skill],
                      title: skillLabel(skill),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _greeting(int hour) {
    if (hour < 11) return 'Guten Morgen';
    if (hour < 18) return 'Guten Tag';
    return 'Guten Abend';
  }
}

class _NextLessonCard extends StatelessWidget {
  const _NextLessonCard({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) => SoftCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next lesson',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(lesson.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('${lesson.durationMinutes} min · ${lesson.objective}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LessonView(lesson: lesson),
                ),
              ),
              child: const Text('Open'),
            ),
          ],
        ),
      );
}
