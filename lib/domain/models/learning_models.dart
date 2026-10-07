import 'progress_models.dart';

export 'progress_models.dart';

enum CefrLevel { preA1, a1, a2, b1, b2, c1 }

/// A learner-selected appearance. This deliberately mirrors, rather than
/// exposes, Flutter's [ThemeMode] so the domain layer stays UI-framework free.
enum AppearancePreference { system, light, dark }

extension AppearancePreferenceLabel on AppearancePreference {
  String get label => switch (this) {
        AppearancePreference.system => 'Use device setting',
        AppearancePreference.light => 'Light',
        AppearancePreference.dark => 'Dark',
      };
}

/// The AI gateway remains the authority for credentials and model routing.
/// This value records the learner's safe provider preference only.
enum AIProviderPreference { automatic, groq, local }

extension AIProviderPreferenceLabel on AIProviderPreference {
  String get label => switch (this) {
        AIProviderPreference.automatic => 'Automatic',
        AIProviderPreference.groq => 'Groq',
        AIProviderPreference.local => 'Local',
      };

  String get description => switch (this) {
        AIProviderPreference.automatic =>
          'Use the cloud tutor when available, with a local fallback.',
        AIProviderPreference.groq => 'Use the configured cloud tutor.',
        AIProviderPreference.local => 'Use the configured local model.',
      };
}

extension CefrLevelLabel on CefrLevel {
  String get label => switch (this) {
        CefrLevel.preA1 => 'A0 / Pre-A1',
        CefrLevel.a1 => 'A1',
        CefrLevel.a2 => 'A2',
        CefrLevel.b1 => 'B1',
        CefrLevel.b2 => 'B2',
        CefrLevel.c1 => 'C1',
      };

  String get description => switch (this) {
        CefrLevel.preA1 => 'Build your first German sounds and phrases.',
        CefrLevel.a1 => 'Handle familiar everyday situations.',
        CefrLevel.a2 => 'Describe familiar routines and experiences.',
        CefrLevel.b1 => 'Communicate independently on common topics.',
        CefrLevel.b2 => 'Speak fluently and structure complex ideas.',
        CefrLevel.c1 => 'Communicate precisely and flexibly.',
      };
}

enum ExerciseKind { multipleChoice, fillBlank, translation, wordOrder }

/// The broad competency an exercise exercises. Drives [SkillScores].
enum SkillArea { vocabulary, grammar, reading, listening, writing, speaking }

extension SkillAreaLabel on SkillArea {
  String get label => switch (this) {
        SkillArea.vocabulary => 'Vocabulary',
        SkillArea.grammar => 'Grammar',
        SkillArea.reading => 'Reading',
        SkillArea.listening => 'Listening',
        SkillArea.writing => 'Writing',
        SkillArea.speaking => 'Speaking',
      };
}

/// A single practice item.
///
/// [options] holds the choices for [ExerciseKind.multipleChoice] and the word
/// bank for [ExerciseKind.wordOrder]; typed exercises leave it empty.
/// [skills] are stable snake_case ids (e.g. `definite_articles`) used for
/// weak-skill tracking; see [skillLabel] for display text.
class Exercise {
  const Exercise({
    required this.id,
    required this.prompt,
    required this.answer,
    required this.explanation,
    required this.skills,
    this.options = const [],
    this.alternatives = const [],
    this.kind = ExerciseKind.multipleChoice,
    this.area = SkillArea.vocabulary,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final String answer;
  final List<String> alternatives;
  final String explanation;
  final List<String> skills;
  final ExerciseKind kind;
  final SkillArea area;

  List<String> get acceptedAnswers => [answer, ...alternatives];
}

/// Turns a skill id such as `definite_articles` into "Definite articles".
String skillLabel(String skillId) {
  if (skillId.isEmpty) return skillId;
  final spaced = skillId.replaceAll('_', ' ');
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

class Lesson {
  const Lesson({
    required this.id,
    required this.level,
    required this.unit,
    required this.title,
    required this.durationMinutes,
    required this.objective,
    required this.introduction,
    required this.examples,
    required this.exercises,
  });

  final String id;
  final CefrLevel level;
  final String unit;
  final String title;
  final int durationMinutes;
  final String objective;
  final String introduction;
  final List<String> examples;
  final List<Exercise> exercises;
}

class SkillScores {
  const SkillScores({
    this.vocabulary = .25,
    this.grammar = .20,
    this.reading = .20,
    this.listening = .10,
    this.writing = .10,
    this.speaking = .10,
  });

  final double vocabulary;
  final double grammar;
  final double reading;
  final double listening;
  final double writing;
  final double speaking;

  Map<String, double> get entries => {
        for (final area in SkillArea.values) area.label: of(area),
      };

  double of(SkillArea area) => switch (area) {
        SkillArea.vocabulary => vocabulary,
        SkillArea.grammar => grammar,
        SkillArea.reading => reading,
        SkillArea.listening => listening,
        SkillArea.writing => writing,
        SkillArea.speaking => speaking,
      };

  /// Exponential moving average: recent answers matter most, and one answer can
  /// never move a score by more than [learningRate].
  SkillScores recordOutcome(SkillArea area, {required bool correct}) {
    final current = of(area);
    final next = current + learningRate * ((correct ? 1.0 : 0.0) - current);
    return SkillScores(
      vocabulary: area == SkillArea.vocabulary ? next : vocabulary,
      grammar: area == SkillArea.grammar ? next : grammar,
      reading: area == SkillArea.reading ? next : reading,
      listening: area == SkillArea.listening ? next : listening,
      writing: area == SkillArea.writing ? next : writing,
      speaking: area == SkillArea.speaking ? next : speaking,
    );
  }

  static const learningRate = .1;
}

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.label,
    required this.kind,
    required this.dueAt,
    this.intervalDays = 0,
  });

  static const lessonRecallKind = 'Lesson recall';
  static const mistakeKind = 'Mistake review';

  final String id;
  final String label;
  final String kind;
  final DateTime dueAt;
  final int intervalDays;

  bool get isDue => !dueAt.isAfter(DateTime.now());
}

class LearningProfile {
  const LearningProfile({
    required this.name,
    required this.nativeLanguage,
    required this.currentLevel,
    required this.targetLevel,
    required this.currentLessonId,
    required this.lessonProgress,
    required this.skillStats,
    required this.recentMistakes,
    required this.reviewItems,
    required this.scores,
    required this.xp,
    required this.streak,
    required this.lastStudyDate,
    required this.dailyGoalMinutes,
    required this.preferredTopics,
    required this.focusSkills,
    required this.appearancePreference,
    required this.aiProviderPreference,
    required this.aiModel,
    required this.voice,
    required this.speechRate,
    required this.advancedAiControls,
    required this.lessonRemindersEnabled,
    required this.reviewRemindersEnabled,
    required this.streakRemindersEnabled,
  });

  static const firstLessonId = 'pre_a1_greetings';

  factory LearningProfile.newLearner({
    required String nativeLanguage,
    required CefrLevel currentLevel,
  }) =>
      LearningProfile(
        name: 'Learner',
        nativeLanguage: nativeLanguage,
        currentLevel: currentLevel,
        targetLevel: CefrLevel.c1,
        currentLessonId: firstLessonId,
        lessonProgress: const {},
        skillStats: const {},
        recentMistakes: const [],
        reviewItems: const [],
        scores: const SkillScores(),
        xp: 0,
        streak: 0,
        lastStudyDate: null,
        dailyGoalMinutes: 15,
        preferredTopics: const ['Everyday life'],
        focusSkills: const ['Vocabulary', 'Speaking'],
        appearancePreference: AppearancePreference.system,
        aiProviderPreference: AIProviderPreference.automatic,
        aiModel: 'Qwen',
        voice: 'Anna',
        speechRate: 230,
        advancedAiControls: false,
        lessonRemindersEnabled: false,
        reviewRemindersEnabled: false,
        streakRemindersEnabled: false,
      );

  final String name;
  final String nativeLanguage;
  final CefrLevel currentLevel;
  final CefrLevel targetLevel;
  final String currentLessonId;
  final Map<String, LessonProgress> lessonProgress;
  final Map<String, SkillStat> skillStats;
  final List<String> recentMistakes;
  final List<ReviewItem> reviewItems;
  final SkillScores scores;
  final int xp;
  final int streak;
  final DateTime? lastStudyDate;
  final int dailyGoalMinutes;
  final List<String> preferredTopics;
  final List<String> focusSkills;
  final AppearancePreference appearancePreference;
  final AIProviderPreference aiProviderPreference;
  final String aiModel;
  final String voice;
  final int speechRate;
  final bool advancedAiControls;
  final bool lessonRemindersEnabled;
  final bool reviewRemindersEnabled;
  final bool streakRemindersEnabled;

  bool isLessonCompleted(String lessonId) =>
      lessonProgress[lessonId]?.isCompleted ?? false;

  int get completedLessonCount =>
      lessonProgress.values.where((progress) => progress.isCompleted).length;

  /// The streak as it stands on [now]: a streak whose last study day is older
  /// than yesterday has already lapsed even though no activity reset it yet.
  int streakAt(DateTime now) {
    final last = lastStudyDate;
    if (last == null) return 0;
    return daysBetween(last, now) > 1 ? 0 : streak;
  }

  LearningProfile copyWith({
    String? name,
    String? nativeLanguage,
    CefrLevel? currentLevel,
    String? currentLessonId,
    Map<String, LessonProgress>? lessonProgress,
    Map<String, SkillStat>? skillStats,
    List<String>? recentMistakes,
    List<ReviewItem>? reviewItems,
    SkillScores? scores,
    int? xp,
    int? streak,
    DateTime? lastStudyDate,
    CefrLevel? targetLevel,
    int? dailyGoalMinutes,
    List<String>? preferredTopics,
    List<String>? focusSkills,
    AppearancePreference? appearancePreference,
    AIProviderPreference? aiProviderPreference,
    String? aiModel,
    String? voice,
    int? speechRate,
    bool? advancedAiControls,
    bool? lessonRemindersEnabled,
    bool? reviewRemindersEnabled,
    bool? streakRemindersEnabled,
  }) =>
      LearningProfile(
        name: name ?? this.name,
        nativeLanguage: nativeLanguage ?? this.nativeLanguage,
        currentLevel: currentLevel ?? this.currentLevel,
        targetLevel: targetLevel ?? this.targetLevel,
        currentLessonId: currentLessonId ?? this.currentLessonId,
        lessonProgress: lessonProgress ?? this.lessonProgress,
        skillStats: skillStats ?? this.skillStats,
        recentMistakes: recentMistakes ?? this.recentMistakes,
        reviewItems: reviewItems ?? this.reviewItems,
        scores: scores ?? this.scores,
        xp: xp ?? this.xp,
        streak: streak ?? this.streak,
        lastStudyDate: lastStudyDate ?? this.lastStudyDate,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        preferredTopics: preferredTopics ?? this.preferredTopics,
        focusSkills: focusSkills ?? this.focusSkills,
        appearancePreference: appearancePreference ?? this.appearancePreference,
        aiProviderPreference: aiProviderPreference ?? this.aiProviderPreference,
        aiModel: aiModel ?? this.aiModel,
        voice: voice ?? this.voice,
        speechRate: speechRate ?? this.speechRate,
        advancedAiControls: advancedAiControls ?? this.advancedAiControls,
        lessonRemindersEnabled:
            lessonRemindersEnabled ?? this.lessonRemindersEnabled,
        reviewRemindersEnabled:
            reviewRemindersEnabled ?? this.reviewRemindersEnabled,
        streakRemindersEnabled:
            streakRemindersEnabled ?? this.streakRemindersEnabled,
      );

  /// Removes learning activity while retaining account and product settings.
  ///
  /// Built from the full constructor (not [copyWith]) so that nullable state
  /// such as [lastStudyDate] can actually be cleared.
  LearningProfile resetLearningProgress() => LearningProfile(
        name: name,
        nativeLanguage: nativeLanguage,
        currentLevel: currentLevel,
        targetLevel: targetLevel,
        currentLessonId: firstLessonId,
        lessonProgress: const {},
        skillStats: const {},
        recentMistakes: const [],
        reviewItems: const [],
        scores: const SkillScores(),
        xp: 0,
        streak: 0,
        lastStudyDate: null,
        dailyGoalMinutes: dailyGoalMinutes,
        preferredTopics: preferredTopics,
        focusSkills: focusSkills,
        appearancePreference: appearancePreference,
        aiProviderPreference: aiProviderPreference,
        aiModel: aiModel,
        voice: voice,
        speechRate: speechRate,
        advancedAiControls: advancedAiControls,
        lessonRemindersEnabled: lessonRemindersEnabled,
        reviewRemindersEnabled: reviewRemindersEnabled,
        streakRemindersEnabled: streakRemindersEnabled,
      );
}

class CoachReply {
  const CoachReply({
    required this.original,
    required this.corrected,
    required this.explanation,
    required this.followUp,
    required this.wasCorrect,
  });

  final String original;
  final String corrected;
  final String explanation;
  final String followUp;
  final bool wasCorrect;
}

class TutorReply {
  const TutorReply({
    required this.reply,
    this.correction,
    this.explanation,
    required this.followUp,
  });

  final String reply;
  final String? correction;
  final String? explanation;
  final String followUp;
}

class AudioCapture {
  const AudioCapture({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final List<int> bytes;
  final String filename;
  final String mimeType;
}

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.language,
  });

  final String text;
  final String language;
}
