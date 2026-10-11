import '../models/curriculum.dart';
import '../models/learning_models.dart';
import 'flashcard_scheduler.dart';

/// "yyyy-MM-dd" in local time: the key for per-day counters.
String dayKey(DateTime time) => '${time.year.toString().padLeft(4, '0')}-'
    '${time.month.toString().padLeft(2, '0')}-'
    '${time.day.toString().padLeft(2, '0')}';

/// A card with its place in the schedule.
class DeckCard {
  const DeckCard(this.item, this.state);

  final VocabItem item;

  /// Null for a card the learner has not seen yet.
  final CardState? state;

  bool get isNew => state == null;

  /// Once a card has been recalled a couple of times it flips to the harder
  /// direction: from the English meaning, recall the German. Producing a word is
  /// a stronger memory test than recognising it.
  bool get asksForGerman => (state?.reps ?? 0) >= 2;
}

/// How the learner's deck looks right now.
class DeckSummary {
  const DeckSummary({
    required this.due,
    required this.newAvailable,
    required this.learning,
    required this.mature,
    required this.total,
  });

  final int due;
  final int newAvailable;
  final int learning;
  final int mature;
  final int total;

  /// What a session offers: everything due plus the day's allowance of new.
  int get ready => due + newAvailable;
}

/// Builds flashcard sessions from the vocabulary of lessons the learner has
/// started, so they are only quizzed on words they have met.
class FlashcardDeck {
  const FlashcardDeck({this.scheduler = const FlashcardScheduler()});

  final FlashcardScheduler scheduler;

  static const defaultSessionLimit = 20;

  /// New cards per day, scaled to the daily study goal (about one per three
  /// minutes) and kept within a sensible range.
  static int dailyNewLimit(LearningProfile profile) =>
      (profile.dailyGoalMinutes / 3).round().clamp(3, 15);

  /// Every card the learner has unlocked, in curriculum order.
  List<VocabItem> unlocked(LearningProfile profile, Curriculum curriculum) => [
        for (final lesson in curriculum.lessons)
          if (profile.lessonProgress.containsKey(lesson.id))
            ...lesson.vocabulary,
      ];

  int newAllowance(LearningProfile profile, DateTime now) {
    final progress = profile.flashcards;
    final used = progress.day == dayKey(now) ? progress.newToday : 0;
    return (dailyNewLimit(profile) - used).clamp(0, 1 << 20);
  }

  DeckSummary summary(
    LearningProfile profile,
    Curriculum curriculum,
    DateTime now,
  ) {
    final cards = unlocked(profile, curriculum);
    final states = profile.flashcards.states;
    var due = 0, learning = 0, mature = 0, fresh = 0;
    for (final card in cards) {
      final state = states[card.id];
      if (state == null) {
        fresh++;
      } else {
        if (state.isDue(now)) due++;
        state.isMature ? mature++ : learning++;
      }
    }
    return DeckSummary(
      due: due,
      newAvailable: fresh.clamp(0, newAllowance(profile, now)),
      learning: learning,
      mature: mature,
      total: cards.length,
    );
  }

  /// Due cards first, most overdue at the front, then new cards up to the day's
  /// allowance, capped at [limit].
  List<DeckCard> session(
    LearningProfile profile,
    Curriculum curriculum,
    DateTime now, {
    int limit = defaultSessionLimit,
  }) {
    final states = profile.flashcards.states;
    final due = <DeckCard>[];
    final fresh = <DeckCard>[];
    for (final card in unlocked(profile, curriculum)) {
      final state = states[card.id];
      if (state == null) {
        fresh.add(DeckCard(card, null));
      } else if (state.isDue(now)) {
        due.add(DeckCard(card, state));
      }
    }
    due.sort((a, b) => a.state!.dueAt.compareTo(b.state!.dueAt));

    final newCards = fresh.take(newAllowance(profile, now));
    return [...due, ...newCards].take(limit).toList();
  }
}

/// One answered card.
class CardReview {
  const CardReview(this.card, this.rating);

  final DeckCard card;
  final CardRating rating;
}
