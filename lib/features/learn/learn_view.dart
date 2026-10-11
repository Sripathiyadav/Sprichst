import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/pressable.dart';
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
        padding: pageListPadding(context),
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
                  reason: lesson.id == currentId
                      ? app.recommendation?.reasons.firstOrNull
                      : null,
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
    this.reason,
  });

  final Lesson lesson;
  final LessonStatus status;
  final bool isCurrent;

  /// Why this lesson is recommended, shown on the current lesson.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = status == LessonStatus.completed;
    final highlighted = isCurrent && !done;
    final background = done
        ? scheme.tertiary
        : highlighted
            ? scheme.primary
            : context.softSurface;
    final foreground = done
        ? scheme.onTertiary
        : highlighted
            ? scheme.onPrimary
            : scheme.onSurface;
    final label = '${lesson.title}, ${lesson.durationMinutes} minutes, '
        '${_statusLabel()}${lesson.exam == null ? '' : ', ${_examName(lesson.exam!)} exam practice'}'
        '${reason == null ? '' : '. $reason'}';

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: PressableScale(
        child: SoftCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: background,
                  foregroundColor: foreground,
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
                      Text(
                          '${lesson.durationMinutes} min · ${_statusLabel()}'
                          '${lesson.exam == null ? '' : ' · ${_examName(lesson.exam!)} exam practice'}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (reason != null)
                        Text(reason!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: context.accent)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LessonView(lesson: lesson)),
      );

  static String _examName(String exam) =>
      exam == 'testdaf' ? 'TestDaF' : 'Goethe';

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
        color: active ? context.softSurface : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(level.label,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (active)
                const Chip(
                  avatar: Icon(Icons.flag_outlined, size: 18),
                  label: Text('Your level'),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            SkillMeter(
                label: level.description, value: progress, compact: true),
          ],
        ),
      );
}
