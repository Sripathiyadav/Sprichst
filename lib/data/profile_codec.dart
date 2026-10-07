import '../domain/models/learning_models.dart';

typedef DateEncoder = Object Function(DateTime date);
typedef DateDecoder = DateTime Function(Object? raw);

/// Maps [LearningProfile] to and from plain maps. Local storage and Firestore
/// share this so the schema, defaults, and migrations live in one place; only
/// the date representation differs between them.
abstract final class ProfileCodec {
  static Map<String, dynamic> encode(
    LearningProfile profile, {
    required DateEncoder encodeDate,
  }) =>
      {
        'name': profile.name,
        'nativeLanguage': profile.nativeLanguage,
        'currentLevel': profile.currentLevel.name,
        'targetLevel': profile.targetLevel.name,
        'currentLessonId': profile.currentLessonId,
        'lessonProgress': {
          for (final entry in profile.lessonProgress.entries)
            entry.key: {
              'status': entry.value.status.name,
              'attempts': entry.value.attempts,
              'bestCorrect': entry.value.bestCorrect,
              'total': entry.value.total,
            },
        },
        'skillStats': {
          for (final entry in profile.skillStats.entries)
            entry.key: {
              'attempts': entry.value.attempts,
              'correct': entry.value.correct,
            },
        },
        'recentMistakes': profile.recentMistakes,
        'reviewItems': [
          for (final item in profile.reviewItems)
            {
              'id': item.id,
              'label': item.label,
              'kind': item.kind,
              'dueAt': encodeDate(item.dueAt),
              'intervalDays': item.intervalDays,
            },
        ],
        'scores': {
          for (final area in SkillArea.values)
            area.name: profile.scores.of(area),
        },
        'xp': profile.xp,
        'streak': profile.streak,
        if (profile.lastStudyDate != null)
          'lastStudyDate': encodeDate(profile.lastStudyDate!),
        'dailyGoalMinutes': profile.dailyGoalMinutes,
        'preferredTopics': profile.preferredTopics,
        'focusSkills': profile.focusSkills,
        'appearancePreference': profile.appearancePreference.name,
        'aiProviderPreference': profile.aiProviderPreference.name,
        'aiModel': profile.aiModel,
        'voice': profile.voice,
        'speechRate': profile.speechRate,
        'advancedAiControls': profile.advancedAiControls,
        'lessonRemindersEnabled': profile.lessonRemindersEnabled,
        'reviewRemindersEnabled': profile.reviewRemindersEnabled,
        'streakRemindersEnabled': profile.streakRemindersEnabled,
      };

  /// Tolerates every earlier schema: missing fields take defaults, a bare
  /// `completedLessonIds` list becomes completed [LessonProgress], and scores
  /// stored flat at the top level are still read.
  static LearningProfile decode(
    Map<String, dynamic> data, {
    required DateDecoder decodeDate,
  }) {
    final defaults = LearningProfile.newLearner(
      nativeLanguage: 'English',
      currentLevel: CefrLevel.preA1,
    );
    final scores = _map(data['scores']) ?? data;

    final lessonProgress = <String, LessonProgress>{
      for (final id in _list<String>(data['completedLessonIds']))
        id: const LessonProgress(status: LessonStatus.completed),
      for (final entry in (_map(data['lessonProgress']) ?? const {}).entries)
        entry.key: _lessonProgress(_map(entry.value) ?? const {}),
    };

    return LearningProfile(
      name: data['name'] as String? ?? defaults.name,
      nativeLanguage: data['nativeLanguage'] as String? ?? 'English',
      currentLevel:
          _enum(CefrLevel.values, data['currentLevel'], CefrLevel.preA1),
      targetLevel: _enum(CefrLevel.values, data['targetLevel'], CefrLevel.c1),
      currentLessonId:
          data['currentLessonId'] as String? ?? LearningProfile.firstLessonId,
      lessonProgress: lessonProgress,
      skillStats: {
        for (final entry in (_map(data['skillStats']) ?? const {}).entries)
          entry.key: SkillStat(
            attempts: _int(_map(entry.value)?['attempts'], 0),
            correct: _int(_map(entry.value)?['correct'], 0),
          ),
      },
      recentMistakes: _list<String>(data['recentMistakes']),
      reviewItems: [
        for (final raw in _list<Object?>(data['reviewItems']))
          if (_map(raw) case final item?)
            ReviewItem(
              id: item['id'] as String,
              label: item['label'] as String,
              kind: item['kind'] as String,
              dueAt: decodeDate(item['dueAt']),
              intervalDays: _int(item['intervalDays'], 0),
            ),
      ],
      scores: SkillScores(
        vocabulary: _double(scores['vocabulary'], .25),
        grammar: _double(scores['grammar'], .20),
        reading: _double(scores['reading'], .20),
        listening: _double(scores['listening'], .10),
        writing: _double(scores['writing'], .10),
        speaking: _double(scores['speaking'], .10),
      ),
      xp: _int(data['xp'], 0),
      streak: _int(data['streak'], 0),
      lastStudyDate: data['lastStudyDate'] == null
          ? null
          : decodeDate(data['lastStudyDate']),
      dailyGoalMinutes:
          _int(data['dailyGoalMinutes'], defaults.dailyGoalMinutes),
      preferredTopics: _list<String>(
        data['preferredTopics'],
        fallback: defaults.preferredTopics,
      ),
      focusSkills: _list<String>(
        data['focusSkills'],
        fallback: defaults.focusSkills,
      ),
      appearancePreference: _enum(
        AppearancePreference.values,
        data['appearancePreference'],
        AppearancePreference.system,
      ),
      aiProviderPreference: _enum(
        AIProviderPreference.values,
        data['aiProviderPreference'],
        AIProviderPreference.automatic,
      ),
      aiModel: data['aiModel'] as String? ?? defaults.aiModel,
      voice: data['voice'] as String? ?? defaults.voice,
      speechRate: _int(data['speechRate'], defaults.speechRate),
      advancedAiControls: data['advancedAiControls'] as bool? ?? false,
      lessonRemindersEnabled: data['lessonRemindersEnabled'] as bool? ?? false,
      reviewRemindersEnabled: data['reviewRemindersEnabled'] as bool? ?? false,
      streakRemindersEnabled: data['streakRemindersEnabled'] as bool? ?? false,
    );
  }

  static LessonProgress _lessonProgress(Map<String, dynamic> raw) =>
      LessonProgress(
        status:
            _enum(LessonStatus.values, raw['status'], LessonStatus.notStarted),
        attempts: _int(raw['attempts'], 0),
        bestCorrect: _int(raw['bestCorrect'], 0),
        total: _int(raw['total'], 0),
      );

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.asNameMap()[name] ?? fallback;

  static int _int(Object? value, int fallback) =>
      (value as num?)?.toInt() ?? fallback;

  static double _double(Object? value, double fallback) =>
      (value as num?)?.toDouble() ?? fallback;

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static List<T> _list<T>(Object? value, {List<T> fallback = const []}) =>
      value is List ? List<T>.from(value) : fallback;
}
