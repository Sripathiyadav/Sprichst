enum CefrLevel { preA1, a1, a2, b1, b2, c1 }

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

enum ExerciseKind { multipleChoice, wordOrder, fillBlank }

class Exercise {
  const Exercise({
    required this.id,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.explanation,
    this.kind = ExerciseKind.multipleChoice,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final String answer;
  final String explanation;
  final ExerciseKind kind;
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
        'Vocabulary': vocabulary,
        'Grammar': grammar,
        'Reading': reading,
        'Listening': listening,
        'Writing': writing,
        'Speaking': speaking,
      };

  SkillScores boosted({double vocabulary = 0, double grammar = 0}) =>
      SkillScores(
        vocabulary: (this.vocabulary + vocabulary).clamp(0, 1).toDouble(),
        grammar: (this.grammar + grammar).clamp(0, 1).toDouble(),
        reading: reading,
        listening: listening,
        writing: writing,
        speaking: speaking,
      );
}

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.label,
    required this.kind,
    required this.dueAt,
    this.intervalDays = 0,
  });

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
    required this.completedLessonIds,
    required this.reviewItems,
    required this.scores,
    required this.xp,
    required this.streak,
    required this.dailyGoalMinutes,
  });

  factory LearningProfile.newLearner({
    required String nativeLanguage,
    required CefrLevel currentLevel,
  }) =>
      LearningProfile(
        name: 'Learner',
        nativeLanguage: nativeLanguage,
        currentLevel: currentLevel,
        targetLevel: CefrLevel.c1,
        currentLessonId: 'pre_a1_greetings',
        completedLessonIds: const [],
        reviewItems: const [],
        scores: const SkillScores(),
        xp: 0,
        streak: 0,
        dailyGoalMinutes: 15,
      );

  final String name;
  final String nativeLanguage;
  final CefrLevel currentLevel;
  final CefrLevel targetLevel;
  final String currentLessonId;
  final List<String> completedLessonIds;
  final List<ReviewItem> reviewItems;
  final SkillScores scores;
  final int xp;
  final int streak;
  final int dailyGoalMinutes;

  LearningProfile copyWith({
    String? name,
    String? nativeLanguage,
    CefrLevel? currentLevel,
    String? currentLessonId,
    List<String>? completedLessonIds,
    List<ReviewItem>? reviewItems,
    SkillScores? scores,
    int? xp,
    int? streak,
  }) =>
      LearningProfile(
        name: name ?? this.name,
        nativeLanguage: nativeLanguage ?? this.nativeLanguage,
        currentLevel: currentLevel ?? this.currentLevel,
        targetLevel: targetLevel,
        currentLessonId: currentLessonId ?? this.currentLessonId,
        completedLessonIds: completedLessonIds ?? this.completedLessonIds,
        reviewItems: reviewItems ?? this.reviewItems,
        scores: scores ?? this.scores,
        xp: xp ?? this.xp,
        streak: streak ?? this.streak,
        dailyGoalMinutes: dailyGoalMinutes,
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
