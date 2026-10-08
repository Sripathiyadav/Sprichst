import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/learning/achievements.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

/// Today's three quests, with progress.
class QuestsCard extends StatelessWidget {
  const QuestsCard({super.key, required this.profile, required this.now});

  final LearningProfile profile;
  final DateTime now;

  static IconData _icon(QuestKind kind) => switch (kind) {
        QuestKind.lesson => Icons.menu_book_rounded,
        QuestKind.cards => Icons.style_rounded,
        QuestKind.games => Icons.sports_esports_rounded,
        QuestKind.correct => Icons.check_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quests = Achievements.todaysQuests(now);
    final state = profile.gamification;
    final done = quests.where((q) => Achievements.isDone(state, q, now)).length;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text('Daily quests', style: theme.textTheme.titleLarge)),
            Text('$done / ${quests.length}',
                style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: AppSpacing.sm),
          for (final quest in quests)
            _QuestRow(
              quest: quest,
              icon: _icon(quest.kind),
              progress: Achievements.progressOf(state, quest, now),
              done: Achievements.isDone(state, quest, now),
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
  });

  final Quest quest;
  final IconData icon;
  final int progress;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = progress.clamp(0, quest.target);
    return Semantics(
      label: '${quest.title}, ${done ? 'done' : '$shown of ${quest.target}'}, '
          '${quest.xp} XP reward',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle_rounded : icon,
                color:
                    done ? context.accent : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quest.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                      )),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: shown / quest.target,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: context.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(done ? 'Done' : '+${quest.xp} XP',
                style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
