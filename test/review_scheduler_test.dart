import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/core/services/review_scheduler.dart';
import 'package:sprichst/domain/models/learning_models.dart';

void main() {
  const scheduler = ReviewScheduler();
  final item = ReviewItem(
      id: 'article',
      label: 'der Tisch',
      kind: 'vocabulary',
      dueAt: DateTime(2026));
  final now = DateTime(2026, 10, 1, 9);

  test('Again schedules an item in ten minutes', () {
    expect(scheduler.schedule(item, ReviewRating.again, now: now).dueAt,
        DateTime(2026, 10, 1, 9, 10));
  });

  test('Good schedules an item in three days', () {
    expect(scheduler.schedule(item, ReviewRating.good, now: now).dueAt,
        DateTime(2026, 10, 4, 9));
  });
}
