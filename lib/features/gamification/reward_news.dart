import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/learning/achievements.dart';
import '../../shared/widgets/app_widgets.dart';
import 'badge_icons.dart';

/// Quests finished and badges earned in the session that just ended.
class RewardNews extends StatelessWidget {
  const RewardNews({super.key, required this.reward});

  final GamificationResult reward;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      color: context.successSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final quest in reward.completedQuests)
            _Line(
              icon: Icons.task_alt_rounded,
              title: 'Quest done: ${quest.title}',
              detail: '+${quest.xp} XP',
            ),
          for (final badge in reward.newBadges)
            _Line(
              icon: badgeIcon(badge.icon),
              title: 'New badge: ${badge.title}',
              detail: badge.description,
            ),
          if (reward.completedQuests.isEmpty && reward.newBadges.isEmpty)
            Text('Nothing new yet.', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.onSuccessSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(color: color)),
                Text(detail,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
