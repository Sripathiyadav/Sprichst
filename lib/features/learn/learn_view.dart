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
      subtitle: 'A path from your first words to C1.',
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
                  number:
                      curriculum.lessons.indexWhere((l) => l.id == lesson.id) +
                          1,
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
    required this.number,
    required this.lesson,
    required this.status,
    required this.isCurrent,
    this.reason,
  });

  final int number;
  final Lesson lesson;
  final LessonStatus status;
  final bool isCurrent;

  /// Why this lesson is recommended, shown on the current lesson.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final done = status == LessonStatus.completed;
    final meta = '${lesson.level.label} · ${lesson.durationMinutes} min'
        '${lesson.exam == null ? '' : ' · ${_examName(lesson.exam!)} exam practice'}';
    final label = '${lesson.title}, lesson $number, $meta, ${_statusLabel()}'
        '${reason == null ? '' : '. $reason'}';

    final chip = switch (status) {
      LessonStatus.completed => const DsChip('Completed',
          icon: Icons.check_circle, tone: ChipTone.success),
      LessonStatus.inProgress => const DsChip('In progress',
          icon: Icons.timelapse, tone: ChipTone.accent),
      LessonStatus.notStarted => isCurrent
          ? const DsChip('Up next',
              icon: Icons.arrow_forward, tone: ChipTone.accent)
          : null,
    };

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: PressableScale(
        child: SoftCard(
          padding: EdgeInsets.zero,
          color: isCurrent && !done ? t.accentSoft : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 56,
                  child: Text(number.toString().padLeft(2, '0'),
                      style: theme.textTheme.headlineLarge?.copyWith(
                          fontSize: 36, color: done ? t.inkMuted : t.ink)),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(meta,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: t.inkMuted)),
                      if (chip != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        chip,
                      ],
                      if (reason != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(reason!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Icon(Icons.chevron_right, color: t.inkMuted),
                ),
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
        color: active ? context.tokens.accentSoft : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(level.label,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (active)
                const DsChip('Your level',
                    icon: Icons.flag_outlined, tone: ChipTone.outline),
            ]),
            const SizedBox(height: AppSpacing.xs),
            SkillMeter(
                label: level.description, value: progress, compact: true),
          ],
        ),
      );
}
