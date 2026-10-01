import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'lesson_view.dart';

class LearnView extends ConsumerWidget {
  const LearnView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    return PageFrame(
      title: 'German roadmap',
      subtitle: 'A curriculum-led path from your first words to C1.',
      child: ListView(
        children: [
          for (final level in CefrLevel.values) ...[
            _LevelRow(
                level: level,
                active: level == profile.currentLevel,
                completed: _progressFor(level, profile)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 24),
          const SectionTitle('Your next lessons'),
          const SizedBox(height: 12),
          for (final lesson in app.lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                child: Row(children: [
                  CircleAvatar(
                      backgroundColor: app.currentLesson?.id == lesson.id
                          ? SprichstTheme.forest
                          : SprichstTheme.sand,
                      foregroundColor: app.currentLesson?.id == lesson.id
                          ? Colors.white
                          : SprichstTheme.ink,
                      child: Text('${app.lessons.indexOf(lesson) + 1}')),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(lesson.title,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            '${lesson.level.label} · ${lesson.durationMinutes} min · ${lesson.unit}')
                      ])),
                  IconButton(
                    tooltip: 'Open lesson',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => LessonView(lesson: lesson))),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  double _progressFor(CefrLevel level, LearningProfile profile) {
    if (level.index < profile.currentLevel.index) return 1;
    if (level.index > profile.currentLevel.index) return 0;
    return profile.completedLessonIds.isEmpty ? .08 : .35;
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow(
      {required this.level, required this.active, required this.completed});
  final CefrLevel level;
  final bool active;
  final double completed;

  @override
  Widget build(BuildContext context) => SoftCard(
        color: active ? const Color(0xFFE2F3E6) : Colors.white,
        child: Row(children: [
          Container(
            width: 10,
            height: 52,
            decoration: BoxDecoration(
                color: active ? SprichstTheme.forest : SprichstTheme.sand,
                borderRadius: BorderRadius.circular(20)),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(level.label,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 7),
                SkillMeter(
                    label: level.description, value: completed, compact: true)
              ])),
        ]),
      );
}
