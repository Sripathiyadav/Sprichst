import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/learning/achievements.dart';
import 'package:sprichst/domain/learning/flashcard_deck.dart';
import 'package:sprichst/domain/models/learning_models.dart';

final _now = DateTime(2026, 10, 8, 9);

LearningProfile _learner() => LearningProfile.newLearner(
    nativeLanguage: 'English', currentLevel: CefrLevel.preA1);

void main() {
  group('daily quests', () {
    test('three distinct quests, stable for a day, varying across days', () {
      final today = Achievements.questsFor('2026-10-08');
      expect(today.length, 3);
      expect(today.map((q) => q.kind).toSet().length, 3);
      expect(Achievements.questsFor('2026-10-08').map((q) => q.id),
          today.map((q) => q.id));
      final seen = {
        for (var d = 1; d <= 8; d++)
          Achievements.questsFor('2026-10-0$d').map((q) => q.id).join(),
      };
      expect(seen.length, greaterThan(1));
    });

    test('progress accumulates and pays out once on completion', () {
      final quest = Achievements.todaysQuests(_now).firstWhere(
          (q) => q.kind == QuestKind.cards,
          orElse: () => Achievements.todaysQuests(_now).first);
      final event = QuestEvent(
        lessons: quest.kind == QuestKind.lesson ? quest.target : 0,
        cards: quest.kind == QuestKind.cards ? quest.target : 0,
        games: quest.kind == QuestKind.games ? quest.target : 0,
        correct: quest.kind == QuestKind.correct ? quest.target : 0,
      );
      final first = Achievements.apply(_learner(), event, _now);
      expect(first.completedQuests.map((q) => q.id), [quest.id]);
      expect(first.bonusXp, quest.xp);
      expect(first.profile.xp, quest.xp);
      expect(
          Achievements.isDone(first.profile.gamification, quest, _now), isTrue);

      // Doing it again the same day pays nothing more.
      final second = Achievements.apply(first.profile, event, _now);
      expect(second.completedQuests, isEmpty);
      expect(second.profile.xp, quest.xp);
    });

    test('partial progress is remembered, and a new day starts fresh', () {
      final quest = Achievements.todaysQuests(_now).first;
      final half = QuestEvent(
        lessons: quest.kind == QuestKind.lesson ? 1 : 0,
        cards: quest.kind == QuestKind.cards ? 4 : 0,
        games: quest.kind == QuestKind.games ? 1 : 0,
        correct: quest.kind == QuestKind.correct ? 6 : 0,
      );
      final result = Achievements.apply(_learner(), half, _now);
      final state = result.profile.gamification;
      expect(Achievements.progressOf(state, quest, _now), greaterThan(0));
      final tomorrow = _now.add(const Duration(days: 1));
      expect(Achievements.progressOf(state, quest, tomorrow), 0);
      final next =
          Achievements.apply(result.profile, const QuestEvent(), tomorrow);
      expect(next.profile.gamification.questsDone, isEmpty);
      expect(next.profile.gamification.questDay, dayKey(tomorrow));
    });
  });

  group('badges', () {
    test('ids are unique', () {
      final ids = Achievements.catalogue.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('a brand-new learner has earned nothing', () {
      final result = Achievements.apply(_learner(), const QuestEvent(), _now);
      expect(result.newBadges, isEmpty);
    });

    test('a streak earns its badge once and records when', () {
      final profile = _learner().copyWith(streak: 7);
      final first = Achievements.apply(profile, const QuestEvent(), _now);
      expect(first.newBadges.map((b) => b.id),
          containsAll(['streak_3', 'streak_7']));
      expect(first.profile.gamification.badges['streak_7'], _now);
      final again = Achievements.apply(first.profile, const QuestEvent(), _now);
      expect(again.newBadges, isEmpty);
    });

    test('articles badge needs enough evidence, not a lucky run', () {
      final lucky = _learner().copyWith(skillStats: {
        'definite_articles': const SkillStat(attempts: 5, correct: 5),
      });
      expect(Achievements.apply(lucky, const QuestEvent(), _now).newBadges,
          isEmpty);
      final proven = _learner().copyWith(skillStats: {
        'definite_articles': const SkillStat(attempts: 40, correct: 36),
      });
      expect(
          Achievements.apply(proven, const QuestEvent(), _now)
              .newBadges
              .map((b) => b.id),
          contains('article_ace'));
    });
  });
}
