import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../learn/lesson_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    final lesson = app.currentLesson!;
    return PageFrame(
      title: 'Guten Abend, ${profile.name}.',
      subtitle: '${profile.currentLevel.label} · ${lesson.unit}',
      trailing: CircleAvatar(
        backgroundColor: SprichstTheme.sand,
        child: Text(profile.name.substring(0, 1)),
      ),
      child: ListView(
        children: [
          SoftCard(
            color: SprichstTheme.forest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TODAY’S PLAN',
                    style: TextStyle(
                        color: Color(0xFFD9F3D8),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Continue ${lesson.title}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Text('${lesson.durationMinutes} minutes · ${lesson.objective}',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: SprichstTheme.forest),
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
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                    width: constraints.maxWidth > 560
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: _MetricCard(
                        value: '${app.dueReviews}',
                        label: 'items due today',
                        icon: Icons.refresh)),
                SizedBox(
                    width: constraints.maxWidth > 560
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: const _MetricCard(
                        value: '2',
                        label: 'mistakes to fix',
                        icon: Icons.auto_fix_high)),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionTitle('Quick practice'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['Vocabulary', 'Articles', 'Grammar', 'Listening']
                .map((label) => ActionChip(
                    label: Text(label),
                    avatar: const Icon(Icons.bolt, size: 17),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '$label practice is ready in the Practice tab.')))))
                .toList(),
          ),
          const SizedBox(height: 24),
          SoftCard(
            color: SprichstTheme.sand,
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: SprichstTheme.coral, size: 32),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(
                        '${profile.streak}-day streak\n${profile.xp} XP earned',
                        style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
          ),
        ],
      ),
    );
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
                backgroundColor: SprichstTheme.sand,
                child: Icon(icon, color: SprichstTheme.forest)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label)
            ]),
          ],
        ),
      );
}
