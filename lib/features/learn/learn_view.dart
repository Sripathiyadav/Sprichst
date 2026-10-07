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
    final curriculum = app.curriculum;
    final currentId = app.currentLesson?.id;

    return PageFrame(
      title: 'German roadmap',
      subtitle: 'A curriculum-led path from your first words to C1.',
      child: ListView(
        children: [
          for (final unit in curriculum.units) ...[
            if (unit != curriculum.units.first)
              const SizedBox(height: AppSpacing.xl),
            SectionTitle('${unit.level.label} · ${unit.title}'),
            const SizedBox(height: AppSpacing.sm),
            for (final lesson in unit.lessons)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LessonTile(
                  lesson: lesson,
                  status: profile.lessonProgress[lesson.id]?.status ??
                      LessonStatus.notStarted,
                  isCurrent: lesson.id == currentId,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Roadmap'),
          const SizedBox(height: AppSpacing.sm),
          for (final level in CefrLevel.values) ...[
            _LevelRow(
              level: level,
              active: level == profile.currentLevel,
              progress:
                  curriculum.levelProgress(level, profile.isLessonCompleted),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.status,
    required this.isCurrent,
  });

  final Lesson lesson;
  final LessonStatus status;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = status == LessonStatus.completed;
    return SoftCard(
      child: Row(children: [
        CircleAvatar(
          backgroundColor:
              done || isCurrent ? scheme.primary : context.softSurface,
          foregroundColor: done || isCurrent
              ? scheme.onPrimary
              : scheme.onSecondaryContainer,
          child: Icon(switch (status) {
            LessonStatus.completed => Icons.check,
            LessonStatus.inProgress => Icons.timelapse,
            LessonStatus.notStarted => Icons.play_arrow_rounded,
          }),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lesson.title,
                  style: Theme.of(context).textTheme.titleMedium),
              Text('${lesson.durationMinutes} min · ${_statusLabel()}'),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Open lesson',
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LessonView(lesson: lesson),
            ),
          ),
        ),
      ]),
    );
  }

  String _statusLabel() => switch (status) {
        LessonStatus.completed => 'Completed',
        LessonStatus.inProgress => 'In progress',
        LessonStatus.notStarted => isCurrent ? 'Up next' : 'Not started',
      };
}

class _LevelRow extends StatelessWidget {
  const _LevelRow(
      {required this.level, required this.active, required this.progress});
  final CefrLevel level;
  final bool active;
  final double progress;

  @override
  Widget build(BuildContext context) => SoftCard(
        color: active ? context.successSurface : null,
        child: Row(children: [
          Container(
            width: 10,
            height: 52,
            decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : context.softSurface,
                borderRadius: BorderRadius.circular(20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(level.label,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 7),
                SkillMeter(
                    label: level.description, value: progress, compact: true)
              ])),
        ]),
      );
}
