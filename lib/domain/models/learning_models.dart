import 'exam_models.dart';
import 'gamification_models.dart';
import 'progress_models.dart';
import 'vocab_models.dart';
import 'voice_models.dart';

export 'exam_models.dart';
export 'gamification_models.dart';
export 'progress_models.dart';
export 'vocab_models.dart';
export 'voice_models.dart';

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

/// How surfaces are drawn: flat and opaque, or translucent "Liquid Glass".
enum SurfaceStyle { standard, glass }

extension SurfaceStyleLabel on SurfaceStyle {
  String get label => switch (this) {
        SurfaceStyle.standard => 'Standard',
        SurfaceStyle.glass => 'Liquid Glass',
      };

  String get description => switch (this) {
        SurfaceStyle.standard => 'Clean, opaque surfaces.',
        SurfaceStyle.glass =>
          'Translucent, light-catching surfaces that let colour show through.',
      };
}

/// The AI gateway remains the authority for credentials and model routing.
/// This value records the learner's safe provider preference only.
enum AIProviderPreference {
  automatic,

  /// The learner's own cloud account (Groq, Gemini, OpenAI…). Stored as
  /// `groq`, its name from when Groq was the only provider, so saved profiles,
  /// older app versions and the Firestore rules all keep working.
  cloud,
  local;

  String get storedName => this == cloud ? 'groq' : name;

  static AIProviderPreference? fromName(Object? name) =>
      name == 'groq' ? cloud : values.asNameMap()[name];
}

extension AIProviderPreferenceLabel on AIProviderPreference {
  String get label => switch (this) {
        AIProviderPreference.automatic => 'Automatic',
        AIProviderPreference.cloud => 'My own AI key',
        AIProviderPreference.local => 'This phone only',
      };

  String get description => switch (this) {
        AIProviderPreference.automatic =>
          'Answers on this phone. Only for what is not downloaded yet does it use your own AI key, if you added one.',
        AIProviderPreference.cloud =>
          'Uses your own account with the AI provider you chose (Groq, Gemini, OpenAI, Claude, Grok…). When its limit runs out or you are offline, you choose whether to continue on this phone.',
        AIProviderPreference.local =>
          'Never send anything off the phone. Needs the models downloaded.',
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

/// Why the learner is studying German. It steers which lessons come first, how
/// vocabulary is chosen, and whether exam practice is offered.
enum LearningGoal { everyday, travel, work, goethe, testdaf }

extension LearningGoalInfo on LearningGoal {
  String get label => switch (this) {
        LearningGoal.everyday => 'Everyday life',
        LearningGoal.travel => 'Travel',
        LearningGoal.work => 'Work',
        LearningGoal.goethe => 'Goethe-Zertifikat',
        LearningGoal.testdaf => 'TestDaF',
      };

  String get description => switch (this) {
        LearningGoal.everyday =>
          'Talk with friends, shop, and handle daily situations.',
        LearningGoal.travel =>
          'Get around, order food, and book places in German-speaking countries.',
        LearningGoal.work =>
          'Write emails, make appointments, and cope at the workplace.',
        LearningGoal.goethe =>
          'Prepare for the Goethe-Zertifikat: Lesen, Hören, Schreiben, Sprechen.',
        LearningGoal.testdaf =>
          'Prepare for TestDaF (B2–C1) for studying at a German university.',
      };

  /// Topic labels (see `preferredTopics`) this goal naturally favours.
  List<String> get topics => switch (this) {
        LearningGoal.everyday => const ['Everyday life', 'Family', 'Food'],
        LearningGoal.travel => const ['Travel', 'Food', 'Culture'],
        LearningGoal.work => const ['Work', 'Everyday life'],
        LearningGoal.goethe => const ['Everyday life', 'Family', 'Work'],
        LearningGoal.testdaf => const ['Study', 'Work', 'Culture'],
      };

  /// Which exam family the goal prepares for, or null for none.
  String? get exam => switch (this) {
        LearningGoal.goethe => 'goethe',
        LearningGoal.testdaf => 'testdaf',
        _ => null,
      };

  bool get isExam => exam != null;
}

/// How a practice item is answered.
///
/// The exam kinds follow the Goethe-Zertifikat and TestDaF modules: `cloze` is
/// the Lückentext / Sprachbausteine, `listening` is Hören (audio, then
/// questions), `writing` is Schreiben (Leitpunkte), `speaking` is Sprechen.
/// Reading tasks are `multipleChoice` over a passage given as `context`.
enum ExerciseKind {
  multipleChoice,
  fillBlank,
  translation,
  wordOrder,
  cloze,
  listening,
  writing,
  speaking,
}

extension ExerciseKindInfo on ExerciseKind {
  /// Recognising the right answer is easier than producing one: the learner
  /// insight compares the two.
  bool get isRecognition =>
      this == ExerciseKind.multipleChoice || this == ExerciseKind.listening;

  String get label => switch (this) {
        ExerciseKind.multipleChoice => 'Choosing answers',
        ExerciseKind.fillBlank => 'Filling gaps',
        ExerciseKind.translation => 'Translating',
        ExerciseKind.wordOrder => 'Building sentences',
        ExerciseKind.cloze => 'Cloze texts',
        ExerciseKind.listening => 'Listening',
        ExerciseKind.writing => 'Writing',
        ExerciseKind.speaking => 'Speaking',
      };
}

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
/// [options] holds the choices for [ExerciseKind.multipleChoice] and
/// [ExerciseKind.listening] and the word bank for [ExerciseKind.wordOrder]; typed
/// exercises leave it empty. [skills] are stable snake_case ids (e.g.
/// `definite_articles`) used for weak-skill tracking; see [skillLabel] for
/// display text.
///
/// Exam-style items add: [context] (a reading text or dialogue shown above the
/// prompt), [audioText] (what is spoken in a listening task), [gaps] (a cloze
/// passage's blanks, numbered `{1}`, `{2}` in [context]), [brief] (a writing
/// task), and [examPart] (e.g. "Lesen Teil 1") naming the exam task it imitates.
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
    this.context,
    this.audioText,
    this.gaps = const [],
    this.brief,
    this.examPart,
    int? difficulty,
  }) : _difficulty = difficulty;

  final String id;
  final String prompt;
  final List<String> options;
  final String answer;
  final List<String> alternatives;
  final String explanation;
  final List<String> skills;
  final ExerciseKind kind;
  final SkillArea area;
  final String? context;
  final String? audioText;
  final List<ClozeGap> gaps;
  final WritingBrief? brief;
  final String? examPart;
  final int? _difficulty;

  /// 1 (easiest) to 3. Unless a lesson sets it, typing is harder than
  /// recognising, and producing longer language is harder still.
  int get difficulty =>
      _difficulty ??
      switch (kind) {
        ExerciseKind.multipleChoice || ExerciseKind.listening => 1,
        ExerciseKind.fillBlank ||
        ExerciseKind.wordOrder ||
        ExerciseKind.cloze =>
          2,
        ExerciseKind.translation ||
        ExerciseKind.writing ||
        ExerciseKind.speaking =>
          3,
      };

  bool get isExamStyle => examPart != null;

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
    this.vocabulary = const [],
    this.topics = const [],
    this.goals = const [],
    this.requires = const [],
    this.exam,
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

  /// Words this lesson teaches: they become flashcards once the lesson is
  /// started, and "known vocabulary" the tutor reuses once it is completed.
  final List<VocabItem> vocabulary;

  /// Topic labels (matching `preferredTopics`) this lesson belongs to.
  final List<String> topics;

  /// Goals this lesson especially serves. Empty means it is core for everyone.
  final List<LearningGoal> goals;

  /// Lessons that should be finished first. Empty means no prerequisite.
  final List<String> requires;

  /// `goethe` or `testdaf` for lessons built around that exam's task types.
  final String? exam;
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
    required this.goal,
    required this.currentLessonId,
    required this.lessonProgress,
    required this.skillStats,
    required this.exerciseStats,
    required this.kindStats,
    required this.areaStats,
    required this.flashcards,
    required this.gamification,
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
    required this.surfaceStyle,
    required this.glassIntensity,
    required this.aiProviderPreference,
    required this.aiModel,
    required this.voice,
    required this.speechRate,
    required this.voicePauseMs,
    required this.advancedAiControls,
    required this.lessonRemindersEnabled,
    required this.reviewRemindersEnabled,
    required this.streakRemindersEnabled,
  });

  static const firstLessonId = 'pre_a1_greetings';

  /// Liquid Glass strength, 0 (barely there) to 100 (most see-through).
  static const defaultGlassIntensity = 60;

  factory LearningProfile.newLearner({
    required String nativeLanguage,
    required CefrLevel currentLevel,
  }) =>
      LearningProfile(
        name: 'Learner',
        nativeLanguage: nativeLanguage,
        currentLevel: currentLevel,
        targetLevel: CefrLevel.c1,
        goal: LearningGoal.everyday,
        currentLessonId: firstLessonId,
        lessonProgress: const {},
        skillStats: const {},
        exerciseStats: const {},
        kindStats: const {},
        areaStats: const {},
        flashcards: const FlashcardProgress(),
        gamification: const GamificationState(),
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
        surfaceStyle: SurfaceStyle.standard,
        glassIntensity: defaultGlassIntensity,
        aiProviderPreference: AIProviderPreference.automatic,
        aiModel: 'Qwen',
        voice: defaultVoiceId,
        speechRate: defaultSpeechRate,
        voicePauseMs: defaultVoicePauseMs,
        advancedAiControls: false,
        lessonRemindersEnabled: false,
        reviewRemindersEnabled: false,
        streakRemindersEnabled: false,
      );

  final String name;
  final String nativeLanguage;
  final CefrLevel currentLevel;
  final CefrLevel targetLevel;
  final LearningGoal goal;
  final String currentLessonId;
  final Map<String, LessonProgress> lessonProgress;
  final Map<String, SkillStat> skillStats;
  final Map<String, ExerciseStat> exerciseStats;

  /// Accuracy by how items are answered (keyed by [ExerciseKind.name]); shows
  /// whether the learner recognises more than they can produce.
  final Map<String, SkillStat> kindStats;

  /// Accuracy by skill area (keyed by [SkillArea.name]): the four Goethe skills
  /// plus vocabulary and grammar. Drives exam readiness.
  final Map<String, SkillStat> areaStats;
  final FlashcardProgress flashcards;
  final GamificationState gamification;
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
  final SurfaceStyle surfaceStyle;
  final int glassIntensity;
  final AIProviderPreference aiProviderPreference;
  final String aiModel;
  final String voice;
  final int speechRate;

  /// How long a pause ends your turn in hands-free voice mode.
  final int voicePauseMs;
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
    Map<String, ExerciseStat>? exerciseStats,
    List<String>? recentMistakes,
    List<ReviewItem>? reviewItems,
    SkillScores? scores,
    int? xp,
    int? streak,
    DateTime? lastStudyDate,
    CefrLevel? targetLevel,
    LearningGoal? goal,
    Map<String, SkillStat>? kindStats,
    Map<String, SkillStat>? areaStats,
    FlashcardProgress? flashcards,
    GamificationState? gamification,
    int? dailyGoalMinutes,
    List<String>? preferredTopics,
    List<String>? focusSkills,
    AppearancePreference? appearancePreference,
    SurfaceStyle? surfaceStyle,
    int? glassIntensity,
    AIProviderPreference? aiProviderPreference,
    String? aiModel,
    String? voice,
    int? speechRate,
    int? voicePauseMs,
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
        goal: goal ?? this.goal,
        currentLessonId: currentLessonId ?? this.currentLessonId,
        lessonProgress: lessonProgress ?? this.lessonProgress,
        skillStats: skillStats ?? this.skillStats,
        exerciseStats: exerciseStats ?? this.exerciseStats,
        kindStats: kindStats ?? this.kindStats,
        areaStats: areaStats ?? this.areaStats,
        flashcards: flashcards ?? this.flashcards,
        gamification: gamification ?? this.gamification,
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
        surfaceStyle: surfaceStyle ?? this.surfaceStyle,
        glassIntensity: (glassIntensity ?? this.glassIntensity).clamp(0, 100),
        aiProviderPreference: aiProviderPreference ?? this.aiProviderPreference,
        aiModel: aiModel ?? this.aiModel,
        voice: voice ?? this.voice,
        speechRate: speechRate ?? this.speechRate,
        voicePauseMs: voicePauseMs ?? this.voicePauseMs,
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
        goal: goal,
        currentLessonId: firstLessonId,
        lessonProgress: const {},
        skillStats: const {},
        exerciseStats: const {},
        kindStats: const {},
        areaStats: const {},
        flashcards: const FlashcardProgress(),
        gamification: const GamificationState(),
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
        surfaceStyle: surfaceStyle,
        glassIntensity: glassIntensity,
        aiProviderPreference: aiProviderPreference,
        aiModel: aiModel,
        voice: voice,
        speechRate: speechRate,
        voicePauseMs: voicePauseMs,
        advancedAiControls: advancedAiControls,
        lessonRemindersEnabled: lessonRemindersEnabled,
        reviewRemindersEnabled: reviewRemindersEnabled,
        streakRemindersEnabled: streakRemindersEnabled,
      );
}

/// The compact, trusted learner state shared with the AI tutor. Learning
/// signals only: name and provider preferences never leave the device. (The
/// chosen voice and speed are sent only with a request to speak.)
class TutorContext {
  const TutorContext({
    required this.level,
    this.unit,
    this.lesson,
    this.weakSkills = const [],
    this.knownVocabulary = const [],
    this.recentMistakes = const [],
    this.conversation = const [],
  });

  final String level;
  final String? unit;
  final String? lesson;
  final List<String> weakSkills;
  final List<String> knownVocabulary;
  final List<String> recentMistakes;

  /// The last few turns of the current coach conversation, oldest first, so
  /// the tutor can answer what was said and not ask it again. Only chat uses
  /// it; the name is still never included.
  final List<ConversationTurn> conversation;

  TutorContext withConversation(List<ConversationTurn> turns) => TutorContext(
        level: level,
        unit: unit,
        lesson: lesson,
        weakSkills: weakSkills,
        knownVocabulary: knownVocabulary,
        recentMistakes: recentMistakes,
        conversation: turns,
      );
}

/// One line of the coach conversation: what the learner said, or what the
/// tutor said back (its reply and its question).
class ConversationTurn {
  const ConversationTurn.learner(this.text) : fromLearner = true;
  const ConversationTurn.tutor(this.text) : fromLearner = false;

  final bool fromLearner;
  final String text;
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
