import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_button.dart';
import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/pressable.dart';
import 'lesson_view.dart';

/// The course, one level at a time. It opens on the learner's level; the tabs
/// show any other level, and every lesson there can be opened.
class LearnView extends ConsumerStatefulWidget {
  const LearnView({super.key});

  @override
  ConsumerState<LearnView> createState() => _LearnViewState();
}

class _LearnViewState extends ConsumerState<LearnView> {
  /// The level being shown; null follows the learner's level.
  CefrLevel? _picked;

  /// The lesson the list opens on: the current one, or the first unfinished
  /// one of another level.
  final _anchor = GlobalKey();

  /// The level the list was last scrolled for, so it jumps once per level.
  CefrLevel? _scrolledFor;

  void _scrollToAnchor(CefrLevel shown) {
    if (_scrolledFor == shown) return;
    _scrolledFor = shown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _anchor.currentContext;
      if (anchor != null) Scrollable.ensureVisible(anchor, alignment: .1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    final curriculum = app.curriculum;
    final current = app.currentLesson;
    final levels = [
      for (final level in CefrLevel.values)
        if (curriculum.lessonsAt(level).isNotEmpty) level,
    ];
    final shown = _picked ?? profile.currentLevel;
    final units = curriculum.units.where((u) => u.level == shown).toList();
    final anchorId = shown == current?.level
        ? current!.id
        : curriculum
            .lessonsAt(shown)
            .where((l) => !profile.isLessonCompleted(l.id))
            .firstOrNull
            ?.id;
    final completed = profile.completedLessonCount;
    _scrollToAnchor(shown);

    final header = [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: EditorialNumber(
              value: completed,
              label: 'Lessons completed',
              unit: completed == 1 ? 'lesson' : 'lessons',
              size: EditorialSize.numeral,
              disc: completed > 0,
            ),
          ),
          SizedBox(
            width: 130,
            child: LevelGauge(
              level: profile.currentLevel,
              progress: curriculum.levelProgress(
                  profile.currentLevel, profile.isLessonCompleted),
            ),
          ),
        ],
      ),
      if (current != null) ...[
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          key: const ValueKey('learn-continue'),
          label: 'Continue: ${current.title}',
          block: true,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => LessonView(lesson: current))),
        ),
      ],
      if (levels.length > 1) ...[
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final level in levels)
              ChoiceChip(
                key: ValueKey('level-tab-${level.name}'),
                label: Text(level.label),
                selected: level == shown,
                onSelected: (_) => setState(() => _picked = level),
              ),
          ],
        ),
      ],
      const SizedBox(height: AppSpacing.md),
    ];

    final lessons = [
      if (shown != profile.currentLevel) ...[
        FeedbackBanner(
          key: const ValueKey('other-level-note'),
          tone: BannerTone.info,
          title: 'You’re on ${profile.currentLevel.label}',
          message: 'You can open any ${shown.label} lesson.'
              '${current == null ? '' : ' Your plan continues with ${current.title}.'}',
          actionLabel: 'Back to ${profile.currentLevel.label}',
          onAction: () => setState(() => _picked = null),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (units.isEmpty)
        const SoftCard(child: Text('No lessons at this level yet.')),
      for (final unit in units) ...[
        if (unit != units.first) const SizedBox(height: AppSpacing.xl),
        SectionTitle('${unit.level.label} · ${unit.title}'),
        const SizedBox(height: AppSpacing.sm),
        for (final lesson in unit.lessons)
          Padding(
            key: lesson.id == anchorId ? _anchor : null,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _LessonTile(
              number:
                  curriculum.lessons.indexWhere((l) => l.id == lesson.id) + 1,
              lesson: lesson,
              status: profile.lessonProgress[lesson.id]?.status ??
                  LessonStatus.notStarted,
              isCurrent: lesson.id == current?.id,
              reason: lesson.id == current?.id
                  ? app.recommendation?.reasons.firstOrNull
                  : null,
            ),
          ),
      ],
      const SizedBox(height: AppSpacing.xl),
      const MoreLanguagesNote(),
    ];

    return PageFrame(
      title: 'German roadmap',
      trailing: const AccountButton(),
      compactHeading: true,
      scrollsUnderNav: false,
      child: LayoutBuilder(builder: (context, constraints) {
        // The header stays put and only the lessons scroll, unless the screen
        // is too short (or the text too large) to leave the list room.
        final fixed = constraints.maxHeight >= 560 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.5;
        final scroll = SingleChildScrollView(
          padding: pageListPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [if (!fixed) ...header, ...lessons],
          ),
        );
        if (!fixed) return scroll;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...header, Expanded(child: scroll)],
        );
      }),
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
