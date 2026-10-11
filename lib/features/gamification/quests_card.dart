import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/learning/achievements.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

/// Today's three quests, with progress.
class QuestsCard extends StatelessWidget {
  const QuestsCard(
      {super.key, required this.profile, required this.now, this.onStart});

  final LearningProfile profile;
  final DateTime now;

  /// Opens a quest. With it, every quest that is not done has a Start button.
  final ValueChanged<Quest>? onStart;

  static IconData _icon(QuestKind kind) => switch (kind) {
        QuestKind.lesson => Icons.menu_book_outlined,
        QuestKind.cards => Icons.style_outlined,
        QuestKind.games => Icons.sports_esports_outlined,
        QuestKind.correct => Icons.check_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    final quests = Achievements.todaysQuests(now);
    final state = profile.gamification;
    return SoftCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (final quest in quests)
            _QuestRow(
              quest: quest,
              icon: _icon(quest.kind),
              progress: Achievements.progressOf(state, quest, now),
              done: Achievements.isDone(state, quest, now),
              onStart: onStart == null ? null : () => onStart!(quest),
            ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.quest,
    required this.icon,
    required this.progress,
    required this.done,
    this.onStart,
  });

  final Quest quest;
  final IconData icon;
  final int progress;
  final bool done;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = progress.clamp(0, quest.target);
    final t = context.tokens;
    final info = Semantics(
      label: '${quest.title}, ${done ? 'done' : '$shown of ${quest.target}'}, '
          '${quest.xp} XP reward',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : icon,
              color: done ? t.success : t.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quest.title, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: shown / quest.target,
                    minHeight: 8,
                    backgroundColor: t.surfaceSunken,
                    color: done ? t.success : context.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(done ? 'Done' : '+${quest.xp} XP',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: done ? t.success : null)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          // The way in: each quest that is not done starts from here.
          if (!done && onStart != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: ValueKey('start-${quest.kind.name}'),
                onPressed: onStart,
                icon: const Icon(Icons.arrow_forward, size: 20),
                iconAlignment: IconAlignment.end,
                label: Text(_startLabel(quest.kind)),
              ),
            ),
        ],
      ),
    );
  }

  static String _startLabel(QuestKind kind) => switch (kind) {
        QuestKind.lesson => 'Start lesson',
        QuestKind.cards => 'Start flashcards',
        QuestKind.games => 'Play a game',
        QuestKind.correct => 'Start practice',
      };
}
