import 'dart:math' as math;

import '../../domain/models/learning_models.dart';

enum ReviewRating { again, hard, good, easy }

class ReviewScheduler {
  const ReviewScheduler();

  static const againDelay = Duration(minutes: 10);
  static const maxIntervalDays = 180;

  /// Deterministic spaced repetition: AI never decides a review date.
  ///
  /// Each successful recall multiplies the previous interval, so items the
  /// learner knows well return less and less often. Minimum intervals match the
  /// first-review schedule (hard 1 day, good 3 days, easy 7 days); "again"
  /// always resets to a short delay.
  ReviewItem schedule(ReviewItem item, ReviewRating rating, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final previous = item.intervalDays;
    final days = switch (rating) {
      ReviewRating.again => 0,
      ReviewRating.hard => math.max(1, (previous * 1.2).round()),
      ReviewRating.good => math.max(3, (previous * 2.5).round()),
      ReviewRating.easy => math.max(7, (previous * 3.5).round()),
    }
        .clamp(0, maxIntervalDays);

    return ReviewItem(
      id: item.id,
      label: item.label,
      kind: item.kind,
      dueAt: days == 0
          ? current.add(againDelay)
          : current.add(Duration(days: days)),
      intervalDays: days,
    );
  }
}
