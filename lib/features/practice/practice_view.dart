import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../domain/games/game_models.dart';
import '../../domain/learning/exam_readiness.dart';
import '../flashcards/flashcard_session_view.dart';
import '../gamification/quests_card.dart';
import '../games/open_game.dart';
import '../home/plan_card.dart';
import 'mock_exam_view.dart';
import 'practice_session_view.dart';

class PracticeView extends ConsumerWidget {
  const PracticeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final plan = app.plan;
    final now = DateTime.now();
    final reviews = [...app.profile!.reviewItems]
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final skills = app.practisableSkills;

    return PageFrame(
      title: 'Practice',
      subtitle: 'Sprichst picks what to practise from your own answers.',
      child: ListView(
        padding: pageListPadding(context),
        children: [
          if (plan != null) PlanCard(plan: plan),
          const SizedBox(height: AppSpacing.md),
          QuestsCard(profile: app.profile!, now: now),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Flashcards'),
          const SizedBox(height: AppSpacing.sm),
          const _FlashcardsCard(),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Games'),
          const SizedBox(height: AppSpacing.sm),
          const _GamesGrid(),
          if (app.profile!.goal.isExam) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionTitle('Exam training'),
            const SizedBox(height: AppSpacing.sm),
            const _ExamCard(),
          ],
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Review queue'),
          const SizedBox(height: AppSpacing.sm),
          if (reviews.isEmpty)
            const SoftCard(
              child: Text(
                  'Nothing is scheduled yet. Finish a lesson and Sprichst will bring back what you missed at the right time.'),
            )
          else
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < reviews.length && i < 6; i++) ...[
                    if (i > 0) const Divider(),
                    _ReviewRow(item: reviews[i], now: now),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Practise a skill'),
          const SizedBox(height: AppSpacing.sm),
          if (skills.isEmpty)
            const SoftCard(
              child: Text(
                  'Skills appear here once you start a lesson, so you only practise what you have been taught.'),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final skill in skills)
                  ActionChip(
                    avatar: const Icon(Icons.bolt, size: 18),
                    label: Text(skillLabel(skill)),
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
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item, required this.now});

  final ReviewItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final due = !item.dueAt.isAfter(now);
    return ListTile(
      leading: Icon(due ? Icons.notifications_active_outlined : Icons.schedule),
      title: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.kind} · ${_when(item.dueAt, now)}'),
    );
  }

  static String _when(DateTime dueAt, DateTime now) {
    final diff = dueAt.difference(now);
    if (!diff.isNegative && diff.inMinutes > 0) {
      if (diff.inDays >= 1) {
        return 'due in ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'}';
      }
      if (diff.inHours >= 1) return 'due in ${diff.inHours} h';
      return 'due in ${diff.inMinutes} min';
    }
    return 'due now';
  }
}

class _FlashcardsCard extends ConsumerWidget {
  const _FlashcardsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(appControllerProvider).flashcardSummary;
    final ready = summary.ready;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.total == 0
                ? 'Words you learn in lessons appear here as flashcards.'
                : ready == 0
                    ? 'All caught up — come back when cards are due.'
                    : '$ready cards ready',
            style: theme.textTheme.titleMedium,
          ),
          if (summary.total > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${summary.due} due · ${summary.newAvailable} new today · '
              '${summary.mature} well known · ${summary.total} unlocked',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed:
                summary.total == 0 ? null : () => openFlashcards(context, ref),
            icon: const Icon(Icons.style_rounded),
            label: Text(ready == 0 ? 'Nothing due' : 'Review $ready cards'),
          ),
        ],
      ),
    );
  }
}

class _GamesGrid extends ConsumerWidget {
  const _GamesGrid();

  static IconData _icon(GameId game) => switch (game) {
        GameId.articleSwipe => Icons.swipe_rounded,
        GameId.memoryMatch => Icons.grid_view_rounded,
        GameId.wordScramble => Icons.shuffle_rounded,
        GameId.wortle => Icons.spellcheck_rounded,
        GameId.dialogue => Icons.forum_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best =
        ref.watch(appControllerProvider).profile!.gamification.gameBest;
    return LayoutBuilder(builder: (context, box) {
      final enlarged = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
      // Each tile needs room for a title and a sentence beside its icon.
      final twoColumns = box.maxWidth >= 640 && !enlarged;
      final width =
          twoColumns ? (box.maxWidth - AppSpacing.sm) / 2 : box.maxWidth;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final game in GameId.values)
            SizedBox(
              width: width,
              child: _GameTile(
                game: game,
                icon: _icon(game),
                best: best[game.name],
                onTap: () => openGame(context, ref, game),
              ),
            ),
        ],
      );
    });
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.game,
    required this.icon,
    required this.best,
    required this.onTap,
  });

  final GameId game;
  final IconData icon;
  final int? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label:
          '${game.title}. ${game.tagline}${best == null ? '' : ' Best score $best.'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SoftCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.softSurface,
                foregroundColor: theme.colorScheme.onSurface,
                child: Icon(icon),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title, style: theme.textTheme.titleMedium),
                    Text(game.tagline, style: theme.textTheme.bodySmall),
                    if (best != null)
                      Text('Best: $best',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: context.accent)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends ConsumerWidget {
  const _ExamCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final readiness = app.examReadiness;
    final goal = app.profile!.goal;
    final theme = Theme.of(context);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preparing for ${goal.label}',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (readiness != null)
            for (final pillar in readiness.pillars) ...[
              SkillMeter(
                label: '${pillar.module} · ${_status(pillar.status)}',
                value: pillar.accuracy,
                compact: true,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            onPressed: () => openMockExam(context, ref),
            icon: const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('Take a mock exam'),
          ),
        ],
      ),
    );
  }

  static String _status(ReadinessStatus status) => switch (status) {
        ReadinessStatus.notStarted => 'not started',
        ReadinessStatus.building => 'building',
        ReadinessStatus.onTrack => 'on track',
      };
}
