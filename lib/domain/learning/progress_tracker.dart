import '../models/curriculum.dart';
import '../models/learning_models.dart';
import 'exercise_evaluator.dart';

typedef ProgressUpdate = ({LearningProfile profile, int xpEarned});

/// Turns exercise outcomes into learning state: lesson completion, skill
/// statistics, weak skills, mistake reviews, XP and streaks. Every method is a
/// pure function of its inputs, so none of it depends on the UI or on AI.
class ProgressTracker {
  const ProgressTracker();

  static const xpPerLessonAnswer = 10;
  static const xpPerPracticeAnswer = 5;
  static const mistakeReviewDelay = Duration(minutes: 10);
  static const maxRecentMistakes = 10;
  static const _maxMistakeLength = 100;

  /// A skill is "weak" once it has enough evidence and accuracy is below this.
  static const weakAccuracy = .75;
  static const minAttemptsForWeakness = 2;

  /// Marks [lesson] as started. Returns [profile] itself (identical) when the
  /// lesson already has progress, so callers can skip persisting.
  LearningProfile startLesson(LearningProfile profile, Lesson lesson) {
    if (profile.lessonProgress.containsKey(lesson.id)) return profile;
    return profile.copyWith(
      lessonProgress: {
        ...profile.lessonProgress,
        lesson.id: const LessonProgress.started(),
      },
    );
  }

  ProgressUpdate completeLesson(
    LearningProfile profile,
    Lesson lesson,
    Curriculum curriculum,
    List<ExerciseResult> results, {
    required DateTime now,
  }) {
    final previous = profile.lessonProgress[lesson.id];
    final correct = results.where((r) => r.isCorrect).length;
    // XP is for first completion only, so replaying a lesson cannot farm it.
    final xpEarned =
        (previous?.isCompleted ?? false) ? 0 : correct * xpPerLessonAnswer;

    final progress = {
      ...profile.lessonProgress,
      lesson.id: (previous ?? const LessonProgress.started())
          .completedWith(correct: correct, total: results.length),
    };
    final lessonRecall = ReviewItem(
      id: 'lesson-${lesson.id}',
      label: lesson.title,
      kind: ReviewItem.lessonRecallKind,
      dueAt: now.add(mistakeReviewDelay),
    );

    final answered = _recordAnswers(profile, results, now);
    final updated = answered.copyWith(
      lessonProgress: progress,
      reviewItems: _upsertReviews(answered.reviewItems, [lessonRecall]),
      xp: profile.xp + xpEarned,
    );
    final next = curriculum.firstIncomplete(
      (id) => progress[id]?.isCompleted ?? false,
    );
    return (
      profile: updated.copyWith(currentLessonId: next?.id),
      xpEarned: xpEarned,
    );
  }

  ProgressUpdate completePractice(
    LearningProfile profile,
    List<ExerciseResult> results, {
    required DateTime now,
  }) {
    final xpEarned =
        results.where((r) => r.isCorrect).length * xpPerPracticeAnswer;
    final updated = _recordAnswers(profile, results, now);
    return (
      profile: updated.copyWith(xp: profile.xp + xpEarned),
      xpEarned: xpEarned,
    );
  }

  /// Skill ids the learner is struggling with, weakest first.
  ///
  /// Before any evidence exists this falls back to the lowest-scoring broad
  /// areas, so the tutor still receives a sensible hint for new learners.
  List<String> weakSkills(LearningProfile profile, {int limit = 3}) {
    final weak = profile.skillStats.entries
        .where((e) =>
            e.value.attempts >= minAttemptsForWeakness &&
            e.value.accuracy < weakAccuracy)
        .toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));
    return [for (final e in weak.take(limit)) e.key];
  }

  LearningProfile _recordAnswers(
    LearningProfile profile,
    List<ExerciseResult> results,
    DateTime now,
  ) {
    final stats = {...profile.skillStats};
    var scores = profile.scores;
    final mistakes = [...profile.recentMistakes];
    final mistakeReviews = <ReviewItem>[];

    for (final result in results) {
      final exercise = result.exercise;
      for (final skill in exercise.skills) {
        stats[skill] = (stats[skill] ?? const SkillStat())
            .recorded(isCorrect: result.isCorrect);
      }
      scores = scores.recordOutcome(exercise.area, correct: result.isCorrect);
      if (result.isCorrect) continue;

      final entry = _mistakeEntry(exercise);
      mistakes
        ..remove(entry)
        ..add(entry);
      mistakeReviews.add(ReviewItem(
        id: 'exercise-${exercise.id}',
        label: exercise.prompt,
        kind: ReviewItem.mistakeKind,
        dueAt: now.add(mistakeReviewDelay),
      ));
    }

    final overflow = mistakes.length - maxRecentMistakes;
    return _registerStudyDay(
      profile.copyWith(
        skillStats: stats,
        scores: scores,
        recentMistakes: overflow > 0 ? mistakes.sublist(overflow) : mistakes,
        reviewItems: _upsertReviews(profile.reviewItems, mistakeReviews),
      ),
      now,
    );
  }

  String _mistakeEntry(Exercise exercise) {
    final skill = exercise.skills.isEmpty ? 'general' : exercise.skills.first;
    final text = '${skillLabel(skill)}: ${exercise.prompt}';
    return text.length <= _maxMistakeLength
        ? text
        : '${text.substring(0, _maxMistakeLength - 1)}…';
  }

  /// Inserts or replaces items by id in O(existing + incoming).
  List<ReviewItem> _upsertReviews(
    List<ReviewItem> existing,
    List<ReviewItem> incoming,
  ) {
    if (incoming.isEmpty) return existing;
    final byId = {for (final item in existing) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    return byId.values.toList();
  }

  LearningProfile _registerStudyDay(LearningProfile profile, DateTime now) {
    final last = profile.lastStudyDate;
    final gap = last == null ? null : daysBetween(last, now);
    final streak = switch (gap) {
      0 => profile.streak < 1 ? 1 : profile.streak,
      1 => profile.streak + 1,
      _ => 1,
    };
    return profile.copyWith(streak: streak, lastStudyDate: now);
  }
}
