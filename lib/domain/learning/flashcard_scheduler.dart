import 'dart:math' as math;

import '../models/vocab_models.dart';

enum CardRating { again, hard, good, easy }

extension CardRatingLabel on CardRating {
  String get label => switch (this) {
        CardRating.again => 'Again',
        CardRating.hard => 'Hard',
        CardRating.good => 'Good',
        CardRating.easy => 'Easy',
      };

  /// Whether the learner recalled the card, for accuracy statistics.
  bool get recalled => this == CardRating.good || this == CardRating.easy;
}

/// Spaced repetition for flashcards, a deterministic variant of SM-2.
///
/// A forgotten card ("Again") returns within minutes and loses some ease. A
/// remembered card is pushed further out each time: first a day, then three,
/// then the previous gap multiplied by the card's ease, which itself rises for
/// easy cards and falls for hard ones. The growing gaps are the spacing effect:
/// recalling something just as it starts to fade strengthens it most.
class FlashcardScheduler {
  const FlashcardScheduler();

  static const againDelay = Duration(minutes: 10);
  static const maxIntervalDays = 365;
  static const maxEase = 3.0;

  /// The state after reviewing a card that has [state] (null for a new card).
  CardState review(CardState? state, CardRating rating, DateTime now) {
    final previous = state ??
        CardState(dueAt: now); // a new card behaves like reps 0, ease 2.5
    final ease = _nextEase(previous.ease, rating);

    if (rating == CardRating.again) {
      return CardState(
        dueAt: now.add(againDelay),
        intervalDays: 0,
        ease: ease,
        reps: 0,
        lapses: previous.reps > 0 ? previous.lapses + 1 : previous.lapses,
      );
    }

    final days = _nextIntervalDays(previous, rating, ease);
    return CardState(
      dueAt: now.add(Duration(days: days)),
      intervalDays: days,
      ease: ease,
      reps: previous.reps + 1,
      lapses: previous.lapses,
    );
  }

  /// How long until the card returns for each rating, for the buttons' hints.
  Duration interval(CardState? state, CardRating rating) {
    final now = DateTime(2000);
    return review(state, rating, now).dueAt.difference(now);
  }

  double _nextEase(double ease, CardRating rating) {
    final next = switch (rating) {
      CardRating.again => ease - .2,
      CardRating.hard => ease - .15,
      CardRating.good => ease,
      CardRating.easy => ease + .15,
    };
    return next.clamp(CardState.minEase, maxEase);
  }

  int _nextIntervalDays(CardState previous, CardRating rating, double ease) {
    final first = previous.reps == 0;
    final days = switch (rating) {
      CardRating.hard => first ? 1 : previous.intervalDays * 1.2,
      CardRating.good => first
          ? 1
          : previous.reps == 1
              ? 3
              : previous.intervalDays * ease,
      CardRating.easy => first
          ? 4
          : previous.reps == 1
              ? 7
              : previous.intervalDays * ease * 1.3,
      CardRating.again => 0,
    };
    return math.max(1, days.round()).clamp(1, maxIntervalDays);
  }

  /// A short label such as "10 min", "3 days", "2 weeks".
  static String describe(Duration interval) {
    if (interval.inMinutes < 60) {
      return '${math.max(1, interval.inMinutes)} min';
    }
    if (interval.inHours < 24) return '${interval.inHours} h';
    final days = interval.inDays;
    if (days < 14) return days == 1 ? '1 day' : '$days days';
    if (days < 60) return '${(days / 7).round()} weeks';
    return '${(days / 30).round()} months';
  }
}
