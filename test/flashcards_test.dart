import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/data/profile_codec.dart';
import 'package:sprichst/domain/learning/flashcard_deck.dart';
import 'package:sprichst/domain/learning/flashcard_scheduler.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

const _scheduler = FlashcardScheduler();
const _deck = FlashcardDeck();
const _tracker = ProgressTracker();
final _course = Curriculum(loadCourse());
final _now = DateTime(2026, 10, 7, 9);

LearningProfile _learner({int dailyMinutes = 15}) => LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.preA1)
    .copyWith(dailyGoalMinutes: dailyMinutes);

/// A learner who has started the first lesson, so its words are unlocked.
LearningProfile _started() =>
    _tracker.startLesson(_learner(), _course.lessonById('pre_a1_greetings')!);

void main() {
  group('FlashcardScheduler', () {
    test('a good run spaces a card 1, 3, then by its ease', () {
      var state = _scheduler.review(null, CardRating.good, _now);
      expect(state.intervalDays, 1);
      state = _scheduler.review(state, CardRating.good, _now);
      expect(state.intervalDays, 3);
      state = _scheduler.review(state, CardRating.good, _now);
      expect(state.intervalDays, 8); // 3 × 2.5 = 7.5, rounded
      state = _scheduler.review(state, CardRating.good, _now);
      expect(state.intervalDays, 20);
      expect(state.reps, 4);
      expect(state.dueAt, _now.add(const Duration(days: 20)));
    });

    test('forgetting resets the gap, counts a lapse, and lowers ease', () {
      var state = _scheduler.review(null, CardRating.good, _now);
      state = _scheduler.review(state, CardRating.good, _now);
      final forgotten = _scheduler.review(state, CardRating.again, _now);
      expect(forgotten.intervalDays, 0);
      expect(forgotten.dueAt, _now.add(FlashcardScheduler.againDelay));
      expect(forgotten.reps, 0);
      expect(forgotten.lapses, 1);
      expect(forgotten.ease, lessThan(state.ease));
    });

    test('failing a brand-new card is not a lapse', () {
      final state = _scheduler.review(null, CardRating.again, _now);
      expect(state.lapses, 0);
    });

    test('easy cards grow faster and gain ease; hard ones slow and lose it',
        () {
      final base = _scheduler.review(
          _scheduler.review(null, CardRating.good, _now),
          CardRating.good,
          _now);
      final easy = _scheduler.review(base, CardRating.easy, _now);
      final hard = _scheduler.review(base, CardRating.hard, _now);
      final good = _scheduler.review(base, CardRating.good, _now);
      expect(easy.intervalDays, greaterThan(good.intervalDays));
      expect(good.intervalDays, greaterThan(hard.intervalDays));
      expect(easy.ease, greaterThan(base.ease));
      expect(hard.ease, lessThan(base.ease));
    });

    test('ease stays within bounds and intervals are capped', () {
      var state = _scheduler.review(null, CardRating.good, _now);
      for (var i = 0; i < 40; i++) {
        state = _scheduler.review(state, CardRating.again, _now);
      }
      expect(state.ease, CardState.minEase);
      for (var i = 0; i < 40; i++) {
        state = _scheduler.review(state, CardRating.easy, _now);
      }
      expect(state.ease, FlashcardScheduler.maxEase);
      expect(state.intervalDays, FlashcardScheduler.maxIntervalDays);
    });

    test('rating hints are ordered and readable', () {
      final hints = [
        for (final r in CardRating.values) _scheduler.interval(null, r),
      ];
      expect(hints, [...hints]..sort());
      expect(FlashcardScheduler.describe(hints.first), '10 min');
      expect(FlashcardScheduler.describe(const Duration(days: 1)), '1 day');
      expect(FlashcardScheduler.describe(const Duration(days: 3)), '3 days');
      expect(FlashcardScheduler.describe(const Duration(days: 28)), '4 weeks');
      expect(
          FlashcardScheduler.describe(const Duration(days: 120)), '4 months');
    });
  });

  group('FlashcardDeck', () {
    test('only words from lessons the learner has started are offered', () {
      expect(_deck.session(_learner(), _course, _now), isEmpty);
      final cards = _deck.session(_started(), _course, _now);
      expect(cards, isNotEmpty);
      final greetings =
          _course.lessonById('pre_a1_greetings')!.vocabulary.map((v) => v.id);
      // Six words, but only five new cards are allowed per day.
      expect(
          greetings.toSet().containsAll(cards.map((c) => c.item.id)), isTrue);
    });

    test('new cards respect a daily allowance scaled to the study goal', () {
      expect(FlashcardDeck.dailyNewLimit(_learner(dailyMinutes: 15)), 5);
      expect(FlashcardDeck.dailyNewLimit(_learner(dailyMinutes: 5)), 3);
      expect(FlashcardDeck.dailyNewLimit(_learner(dailyMinutes: 60)), 15);

      final profile = _started();
      expect(_deck.session(profile, _course, _now).length, 5);
      expect(_deck.summary(profile, _course, _now).newAvailable, 5);
    });

    test('the allowance is used up within a day and resets the next', () {
      var profile = _started();
      final session = _deck.session(profile, _course, _now);
      profile = _tracker
          .completeFlashcards(profile,
              [for (final c in session) CardReview(c, CardRating.good)],
              now: _now)
          .profile;

      expect(profile.flashcards.newToday, 5);
      final later = _now.add(const Duration(hours: 3));
      expect(_deck.session(profile, _course, later), isEmpty,
          reason: 'five new cards were introduced today and none is due yet');

      final tomorrow = _now.add(const Duration(days: 1));
      final next = _deck.session(profile, _course, tomorrow);
      expect(next.where((c) => !c.isNew), isNotEmpty,
          reason: 'day-one reviews');
      expect(next.where((c) => c.isNew), isNotEmpty,
          reason: 'one new card left');
    });

    test('due cards come first, most overdue at the front', () {
      var profile = _started();
      final ids = _course
          .lessonById('pre_a1_greetings')!
          .vocabulary
          .map((v) => v.id)
          .toList();
      profile = profile.copyWith(
        flashcards: FlashcardProgress(
          day: dayKey(_now),
          newToday: 5,
          states: {
            ids[0]: CardState(dueAt: _now.subtract(const Duration(hours: 1))),
            ids[1]: CardState(dueAt: _now.subtract(const Duration(days: 3))),
            ids[2]: CardState(dueAt: _now.add(const Duration(days: 1))),
          },
        ),
      );
      final session = _deck.session(profile, _course, _now);
      expect(session.map((c) => c.item.id), [ids[1], ids[0]]);
    });

    test('cards flip to recalling the German after two successful reviews', () {
      const word = VocabItem(
          id: 'x/y', german: 'Tisch', english: 'table', article: 'der');
      expect(const DeckCard(word, null).asksForGerman, isFalse);
      expect(DeckCard(word, CardState(dueAt: _now, reps: 1)).asksForGerman,
          isFalse);
      expect(DeckCard(word, CardState(dueAt: _now, reps: 2)).asksForGerman,
          isTrue);
      expect(word.display, 'der Tisch');
    });

    test('the summary separates due, new, learning, and mature cards', () {
      var profile = _started();
      final ids = _course
          .lessonById('pre_a1_greetings')!
          .vocabulary
          .map((v) => v.id)
          .toList();
      profile = profile.copyWith(
        flashcards: FlashcardProgress(
          day: dayKey(_now),
          newToday: 0,
          states: {
            ids[0]: CardState(
                dueAt: _now.subtract(const Duration(hours: 1)),
                intervalDays: 2),
            ids[1]: CardState(
                dueAt: _now.add(const Duration(days: 30)), intervalDays: 30),
          },
        ),
      );
      final summary = _deck.summary(profile, _course, _now);
      expect(summary.due, 1);
      expect(summary.learning, 1);
      expect(summary.mature, 1);
      expect(summary.total, ids.length);
    });
  });

  group('completing a session', () {
    test('reschedules cards, awards XP, extends the streak, and records recall',
        () {
      final profile = _started();
      final session = _deck.session(profile, _course, _now);
      final reviews = [
        CardReview(session[0], CardRating.good),
        CardReview(session[1], CardRating.easy),
        CardReview(session[2], CardRating.again),
      ];
      final update = _tracker.completeFlashcards(profile, reviews, now: _now);

      expect(update.xpEarned, 2 + 2 + 1);
      final states = update.profile.flashcards.states;
      expect(states[session[0].item.id]!.intervalDays, 1);
      expect(states[session[1].item.id]!.intervalDays, 4);
      expect(states[session[2].item.id]!.dueAt,
          _now.add(FlashcardScheduler.againDelay));
      expect(update.profile.streak, 1);
      final vocabulary = update.profile.areaStats['vocabulary']!;
      expect(vocabulary.attempts, 3);
      expect(vocabulary.correct, 2);
    });

    test('a card asked twice in one session counts as new only once', () {
      final profile = _started();
      final card = _deck.session(profile, _course, _now).first;
      final update = _tracker.completeFlashcards(
        profile,
        [CardReview(card, CardRating.again), CardReview(card, CardRating.good)],
        now: _now,
      );
      expect(update.profile.flashcards.newToday, 1);
      expect(update.profile.flashcards.states[card.item.id]!.reps, 1);
    });

    test('flashcard progress survives encoding', () {
      final profile = _started();
      final session = _deck.session(profile, _course, _now);
      final done = _tracker
          .completeFlashcards(
              profile, [CardReview(session.first, CardRating.good)],
              now: _now)
          .profile;
      final decoded = ProfileCodec.decode(
        ProfileCodec.encode(done, encodeDate: (d) => d.toIso8601String()),
        decodeDate: (raw) => DateTime.parse(raw as String),
      );
      final id = session.first.item.id;
      expect(decoded.flashcards.states[id]!.intervalDays, 1);
      expect(decoded.flashcards.states[id]!.dueAt,
          _now.add(const Duration(days: 1)));
      expect(decoded.flashcards.newToday, 1);
      expect(decoded.flashcards.day, '2026-10-07');
    });

    test('resetting progress clears flashcards too', () {
      final profile = _started();
      final session = _deck.session(profile, _course, _now);
      final done = _tracker
          .completeFlashcards(
              profile, [CardReview(session.first, CardRating.good)],
              now: _now)
          .profile;
      expect(done.resetLearningProgress().flashcards.states, isEmpty);
    });
  });
}
