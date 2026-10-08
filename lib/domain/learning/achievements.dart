import '../models/learning_models.dart';
import 'flashcard_deck.dart';

/// What a daily quest asks for.
enum QuestKind { lesson, cards, games, correct }

class Quest {
  const Quest({
    required this.kind,
    required this.title,
    required this.target,
    required this.xp,
  });

  final QuestKind kind;
  final String title;
  final int target;
  final int xp;

  String get id => kind.name;
}

/// Something that happened in a session, in the units quests count.
class QuestEvent {
  const QuestEvent({
    this.lessons = 0,
    this.cards = 0,
    this.games = 0,
    this.correct = 0,
  });

  final int lessons;
  final int cards;
  final int games;
  final int correct;

  bool get isEmpty => lessons + cards + games + correct == 0;

  int of(QuestKind kind) => switch (kind) {
        QuestKind.lesson => lessons,
        QuestKind.cards => cards,
        QuestKind.games => games,
        QuestKind.correct => correct,
      };
}

/// A badge. [icon] is a stable key the UI maps to a symbol, which keeps this
/// layer free of Flutter.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isEarned,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final bool Function(LearningProfile profile) isEarned;
}

/// What an update changed, so the UI can celebrate it.
class GamificationResult {
  const GamificationResult({
    required this.profile,
    this.bonusXp = 0,
    this.completedQuests = const [],
    this.newBadges = const [],
  });

  final LearningProfile profile;
  final int bonusXp;
  final List<Quest> completedQuests;
  final List<Achievement> newBadges;

  bool get hasNews => completedQuests.isNotEmpty || newBadges.isNotEmpty;
}

/// Daily quests and badges, derived from the profile. Quests are chosen by the
/// calendar day, so they are the same all day and need no server; badges are
/// pure predicates over the profile, so they can never get out of step with the
/// learner's real progress.
class Achievements {
  const Achievements._();

  static const questXp = 15;

  static const _templates = <Quest>[
    Quest(
        kind: QuestKind.lesson,
        title: 'Finish a lesson',
        target: 1,
        xp: questXp),
    Quest(
        kind: QuestKind.cards,
        title: 'Review 10 flashcards',
        target: 10,
        xp: questXp),
    Quest(kind: QuestKind.games, title: 'Play 2 games', target: 2, xp: questXp),
    Quest(
        kind: QuestKind.correct,
        title: 'Answer 15 correctly',
        target: 15,
        xp: questXp),
  ];

  /// Three of the four quests, with a different one left out each day.
  static List<Quest> questsFor(String day) {
    final skipped =
        day.codeUnits.fold<int>(0, (a, b) => a + b) % _templates.length;
    return [
      for (var i = 0; i < _templates.length; i++)
        if (i != skipped) _templates[i],
    ];
  }

  static List<Quest> todaysQuests(DateTime now) => questsFor(dayKey(now));

  /// Progress on [quest] today, `0` before anything has happened.
  static int progressOf(GamificationState state, Quest quest, DateTime now) =>
      state.questDay == dayKey(now) ? state.questProgress[quest.id] ?? 0 : 0;

  static bool isDone(GamificationState state, Quest quest, DateTime now) =>
      state.questDay == dayKey(now) && state.questsDone.contains(quest.id);

  /// Applies [event]: counts quest progress, pays out finished quests, and
  /// awards any badge that has become earned. Safe to call with an empty event
  /// to catch badges after other changes.
  static GamificationResult apply(
    LearningProfile profile,
    QuestEvent event,
    DateTime now,
  ) {
    final today = dayKey(now);
    final state = profile.gamification;
    final fresh = state.questDay != today;
    final progress = fresh ? <String, int>{} : {...state.questProgress};
    final done = fresh ? <String>[] : [...state.questsDone];

    final completed = <Quest>[];
    for (final quest in questsFor(today)) {
      final gained = event.of(quest.kind);
      if (gained > 0) progress[quest.id] = (progress[quest.id] ?? 0) + gained;
      if (!done.contains(quest.id) &&
          (progress[quest.id] ?? 0) >= quest.target) {
        done.add(quest.id);
        completed.add(quest);
      }
    }
    final bonus = completed.fold<int>(0, (sum, q) => sum + q.xp);

    var next = profile.copyWith(
      xp: profile.xp + bonus,
      gamification: state.copyWith(
        questDay: today,
        questProgress: progress,
        questsDone: done,
      ),
    );

    final earned = {...next.gamification.badges};
    final newBadges = <Achievement>[];
    for (final badge in catalogue) {
      if (!earned.containsKey(badge.id) && badge.isEarned(next)) {
        earned[badge.id] = now;
        newBadges.add(badge);
      }
    }
    if (newBadges.isNotEmpty) {
      next = next.copyWith(
        gamification: next.gamification.copyWith(badges: earned),
      );
    }

    return GamificationResult(
      profile: next,
      bonusXp: bonus,
      completedQuests: completed,
      newBadges: newBadges,
    );
  }

  static final catalogue = <Achievement>[
    Achievement(
      id: 'first_lesson',
      title: 'Erster Schritt',
      description: 'Complete your first lesson.',
      icon: 'flag',
      isEarned: (p) => p.completedLessonCount >= 1,
    ),
    Achievement(
      id: 'five_lessons',
      title: 'Dranbleiber',
      description: 'Complete five lessons.',
      icon: 'school',
      isEarned: (p) => p.completedLessonCount >= 5,
    ),
    Achievement(
      id: 'perfect_lesson',
      title: 'Volltreffer',
      description: 'Finish a lesson without a single mistake.',
      icon: 'target',
      isEarned: (p) => p.lessonProgress.values
          .any((l) => l.isCompleted && l.total >= 3 && l.bestAccuracy >= 1),
    ),
    Achievement(
      id: 'level_up',
      title: 'Aufsteiger',
      description: 'Reach level A2.',
      icon: 'trending',
      isEarned: (p) => p.currentLevel.index >= CefrLevel.a2.index,
    ),
    Achievement(
      id: 'streak_3',
      title: 'Drei Tage',
      description: 'Study three days in a row.',
      icon: 'fire',
      isEarned: (p) => p.streak >= 3,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Wochenstreak',
      description: 'Study seven days in a row.',
      icon: 'fire',
      isEarned: (p) => p.streak >= 7,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Eiserner Wille',
      description: 'Study thirty days in a row.',
      icon: 'fire',
      isEarned: (p) => p.streak >= 30,
    ),
    Achievement(
      id: 'words_25',
      title: 'Wortschatz',
      description: 'Meet 25 words in your flashcards.',
      icon: 'cards',
      isEarned: (p) => p.flashcards.states.length >= 25,
    ),
    Achievement(
      id: 'words_100',
      title: 'Wörterbuch',
      description: 'Meet 100 words in your flashcards.',
      icon: 'cards',
      isEarned: (p) => p.flashcards.states.length >= 100,
    ),
    Achievement(
      id: 'long_memory',
      title: 'Langzeitgedächtnis',
      description: 'Bring 10 cards to a three-week memory.',
      icon: 'memory',
      isEarned: (p) =>
          p.flashcards.states.values.where((s) => s.isMature).length >= 10,
    ),
    Achievement(
      id: 'first_game',
      title: 'Spielkind',
      description: 'Play your first game.',
      icon: 'game',
      isEarned: (p) => p.gamification.gamesPlayed >= 1,
    ),
    Achievement(
      id: 'games_10',
      title: 'Spielefan',
      description: 'Play ten games.',
      icon: 'game',
      isEarned: (p) => p.gamification.gamesPlayed >= 10,
    ),
    Achievement(
      id: 'all_games',
      title: 'Allrounder',
      description: 'Play all five games.',
      icon: 'game',
      isEarned: (p) => p.gamification.gameBest.length >= 5,
    ),
    Achievement(
      id: 'article_ace',
      title: 'Artikel-Ass',
      description: 'Reach 85% on der, die, das after 40 answers.',
      icon: 'article',
      isEarned: (p) {
        final stat = p.skillStats['definite_articles'];
        return stat != null &&
            stat.attempts >= 40 &&
            stat.correct / stat.attempts >= .85;
      },
    ),
    Achievement(
      id: 'quest_master',
      title: 'Tagesmeister',
      description: 'Finish all three daily quests.',
      icon: 'quest',
      isEarned: (p) => p.gamification.questsDone.length >= 3,
    ),
    Achievement(
      id: 'xp_500',
      title: '500 XP',
      description: 'Earn 500 XP.',
      icon: 'star',
      isEarned: (p) => p.xp >= 500,
    ),
    Achievement(
      id: 'xp_2000',
      title: '2000 XP',
      description: 'Earn 2000 XP.',
      icon: 'star',
      isEarned: (p) => p.xp >= 2000,
    ),
  ];
}
