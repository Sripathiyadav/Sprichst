import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/domain/games/game_models.dart';
import 'package:sprichst/domain/learning/achievements.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/flashcard_deck.dart';
import 'package:sprichst/domain/learning/flashcard_scheduler.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

void main() {
  dayRotation();
  test('every quest counts and completes from its own activity', () async {
    final repo = InMemoryLearningRepository(LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.a1));
    final container = ProviderContainer(overrides: testOverrides(repo));
    addTearDown(container.dispose);
    final app = container.read(appControllerProvider);
    await app.initialize();
    await app.completeOnboarding(level: CefrLevel.a1);
    final now = DateTime.now();
    final quests = Achievements.todaysQuests(now);

    ExerciseResult right(Exercise e) =>
        const ExerciseEvaluator().evaluate(e, e.answer);

    // 1. A lesson.
    final lesson = app.currentLesson!;
    await app.startLesson(lesson);
    await app
        .completeLesson(lesson, [for (final e in lesson.exercises) right(e)]);

    // 2. Fifteen different questions right (the same one counts once a day).
    final more = app.curriculum.lessonsAt(CefrLevel.a1).skip(1).take(6);
    await app.completePractice([
      for (final l in more)
        for (final e in l.exercises) right(e)
    ]);

    // 3. Flashcards.
    final session = const FlashcardDeck()
        .session(app.profile!, app.curriculum, now, limit: 10);
    await app.completeFlashcards(
        [for (final c in session) CardReview(c, CardRating.good)]);

    // 4. Two games.
    for (var i = 0; i < 2; i++) {
      await app.completeGame(const GameOutcome(
          game: GameId.wortle,
          score: 10,
          correct: 2,
          total: 2,
          stars: 3,
          bestCombo: 2,
          results: []));
    }
    for (final q in quests) {
      expect(Achievements.isDone(app.profile!.gamification, q, now), isTrue,
          reason: '${q.id} was not completed');
    }
  });
}

void dayRotation() {
  test('each day of the rotation has quests that can all be finished', () {
    for (var day = 1; day <= 4; day++) {
      final now = DateTime(2026, 10, day, 9);
      final quests = Achievements.todaysQuests(now);
      var profile = LearningProfile.newLearner(
          nativeLanguage: 'English', currentLevel: CefrLevel.a1);
      profile = Achievements.apply(profile, const QuestEvent(lessons: 1), now)
          .profile;
      profile = Achievements.apply(
              profile, const QuestEvent(cards: 5, clearedCards: true), now)
          .profile;
      profile =
          Achievements.apply(profile, const QuestEvent(games: 2), now).profile;
      profile = Achievements.apply(profile, const QuestEvent(correct: 15), now)
          .profile;
      for (final q in quests) {
        expect(Achievements.isDone(profile.gamification, q, now), isTrue,
            reason: 'day $day: ${q.id}');
      }
    }
  });
}
