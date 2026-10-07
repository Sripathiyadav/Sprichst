enum LessonStatus { notStarted, inProgress, completed }

/// A learner's history with one lesson.
class LessonProgress {
  const LessonProgress({
    required this.status,
    this.attempts = 0,
    this.bestCorrect = 0,
    this.total = 0,
  });

  const LessonProgress.started() : this(status: LessonStatus.inProgress);

  final LessonStatus status;
  final int attempts;
  final int bestCorrect;
  final int total;

  bool get isCompleted => status == LessonStatus.completed;

  /// Best accuracy across attempts, from 0 to 1.
  double get bestAccuracy => total == 0 ? 0 : bestCorrect / total;

  LessonProgress completedWith({required int correct, required int total}) =>
      LessonProgress(
        status: LessonStatus.completed,
        attempts: attempts + 1,
        bestCorrect: correct > bestCorrect ? correct : bestCorrect,
        total: total,
      );
}

/// Running tally of answers for one skill id.
class SkillStat {
  const SkillStat({this.attempts = 0, this.correct = 0});

  final int attempts;
  final int correct;

  /// Laplace-smoothed accuracy. One lucky or unlucky answer cannot swing a
  /// skill to 0% or 100%, which keeps weak-skill ranking stable early on.
  double get accuracy => (correct + 1) / (attempts + 2);

  SkillStat recorded({required bool isCorrect}) => SkillStat(
        attempts: attempts + 1,
        correct: correct + (isCorrect ? 1 : 0),
      );
}

/// Whole calendar days from [from] to [to], ignoring time of day.
///
/// Compared as UTC dates so daylight-saving shifts cannot turn a 23-hour day
/// into zero.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
