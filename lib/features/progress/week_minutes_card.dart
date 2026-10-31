import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

/// Minutes learned on each day of this week, against the daily goal. Shown on
/// Home and Progress. The minutes are counted on this device.
class WeekMinutesCard extends ConsumerWidget {
  const WeekMinutesCard({super.key});

  static const _labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final goal = app.profile?.dailyGoalMinutes ?? 15;
    final now = DateTime.now();
    final week = app.studyTime.week(now);
    final total = app.studyTime.weekMinutes(now);
    final theme = Theme.of(context);
    return SoftCard(
      key: const ValueKey('week-minutes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('Minutes learned', style: theme.textTheme.titleMedium),
              ),
              Text('$total min',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.tokens.inkMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          WeekActivity(
            goal: goal,
            days: [
              for (final day in week)
                DayMinutes(
                  _labels[day.day.weekday - 1],
                  day.minutes,
                  today: day.day.day == now.day &&
                      day.day.month == now.month &&
                      day.day.year == now.year,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
