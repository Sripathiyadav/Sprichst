import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../learn/lesson_view.dart';
import '../practice/practice_session_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    final lesson = app.currentLesson!;
    return PageFrame(
      title: '${_greeting(DateTime.now().hour)}, ${profile.name}.',
      subtitle: '${profile.currentLevel.label} · ${lesson.unit}',
      trailing: ProfileAvatar(name: profile.name),
      child: ListView(
        children: [
          SoftCard(
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TODAY’S PLAN',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Continue ${lesson.title}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: 8),
                Text('${lesson.durationMinutes} minutes · ${lesson.objective}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: () => _openLesson(context, lesson),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Continue lesson'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionTitle('Review'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns =
                  constraints.maxWidth > Breakpoints.twoColumnContent;
              final width = twoColumns
                  ? (constraints.maxWidth - AppSpacing.sm) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                        value: '${app.dueReviews}',
                        label: 'items due today',
                        icon: Icons.refresh),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                        value: '${app.pendingMistakes}',
                        label: 'mistakes to fix',
                        icon: Icons.auto_fix_high),
                  ),
                ],
              );
            },
          ),
          if (app.weakSkills.isNotEmpty) ...[
            const SizedBox(height: 26),
            const SectionTitle('Needs practice'),
            const SizedBox(height: 12),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final skill in app.weakSkills)
                  ActionChip(
                    label: Text(skillLabel(skill)),
                    avatar: const Icon(Icons.bolt, size: 17),
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
          const SizedBox(height: 24),
          SoftCard(
            color: context.softSurface,
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 32),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(
                        '${profile.streakAt(DateTime.now())}-day streak\n${profile.xp} XP earned',
                        style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _greeting(int hour) {
    if (hour < 11) return 'Guten Morgen';
    if (hour < 18) return 'Guten Tag';
    return 'Guten Abend';
  }

  void _openLesson(BuildContext context, Lesson lesson) {
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LessonView(lesson: lesson)));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SoftCard(
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: context.softSurface,
                child:
                    Icon(icon, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label)
            ]),
          ],
        ),
      );
}
