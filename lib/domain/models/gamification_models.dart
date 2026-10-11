/// The learner's game layer: badges, today's quests, and game records.
class GamificationState {
  const GamificationState({
    this.badges = const {},
    this.questDay,
    this.questProgress = const {},
    this.questsDone = const [],
    this.gameBest = const {},
    this.gamesPlayed = 0,
  });

  /// Achievement id → when it was earned.
  final Map<String, DateTime> badges;

  /// The calendar day (`yyyy-MM-dd`) the quest fields describe; a new day starts
  /// fresh quests.
  final String? questDay;
  final Map<String, int> questProgress;
  final List<String> questsDone;

  /// Game id → best score.
  final Map<String, int> gameBest;
  final int gamesPlayed;

  GamificationState copyWith({
    Map<String, DateTime>? badges,
    String? questDay,
    Map<String, int>? questProgress,
    List<String>? questsDone,
    Map<String, int>? gameBest,
    int? gamesPlayed,
  }) =>
      GamificationState(
        badges: badges ?? this.badges,
        questDay: questDay ?? this.questDay,
        questProgress: questProgress ?? this.questProgress,
        questsDone: questsDone ?? this.questsDone,
        gameBest: gameBest ?? this.gameBest,
        gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      );
}
