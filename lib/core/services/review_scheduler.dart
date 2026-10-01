import '../../domain/models/learning_models.dart';

enum ReviewRating { again, hard, good, easy }

class ReviewScheduler {
  const ReviewScheduler();

  /// Deterministic scheduling: AI never decides a review date.
  ReviewItem schedule(ReviewItem item, ReviewRating rating, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final duration = switch (rating) {
      ReviewRating.again => const Duration(minutes: 10),
      ReviewRating.hard => const Duration(days: 1),
      ReviewRating.good => const Duration(days: 3),
      ReviewRating.easy => const Duration(days: 7),
    };
    return ReviewItem(
      id: item.id,
      label: item.label,
      kind: item.kind,
      dueAt: current.add(duration),
      intervalDays: duration.inDays,
    );
  }
}
