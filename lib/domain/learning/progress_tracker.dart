import '../../core/services/review_scheduler.dart';
import '../models/curriculum.dart';
import '../games/game_models.dart';
import 'flashcard_deck.dart';
import 'flashcard_scheduler.dart';
import '../models/learning_models.dart';
import 'exercise_evaluator.dart';
import 'learning_path.dart';

typedef ProgressUpdate = ({
  LearningProfile profile,
  int xpEarned,
  CefrLevel? leveledUpTo,
});

/// What the learner is told after a session.
typedef SessionOutcome = ({int xpEarned, CefrLevel? leveledUpTo});

/// Turns exercise outcomes into learning state: lesson completion, skill and
/// exercise statistics, weak skills, review scheduling, XP, streaks, and level
/// promotion. Every method is a pure function of its inputs, so none of it
/// depends on the UI or on AI.
class ProgressTracker {
  const ProgressTracker({
    this.scheduler = const ReviewScheduler(),
    this.path = const LearningPath(),
    this.cards = const FlashcardScheduler(),
  });

  final ReviewScheduler scheduler;
  final FlashcardScheduler cards;
  final LearningPath path;

  static const xpPerLessonAnswer = 10;
  static const xpPerPracticeAnswer = 5;
  static const xpPerRecalledCard = 2;
  static const xpPerForgottenCard = 1;
  static const mistakeReviewDelay = Duration(minutes: 10);
  static const maxRecentMistakes = 10;
  static const _maxMistakeLength = 100;

  /// A skill is "weak" once it has enough evidence and accuracy is below this.
  static const weakAccuracy = .75;
  static const minAttemptsForWeakness = 2;

  /// A mistake is considered mastered when it is answered correctly again after
  /// its review has already been pushed out to at least this many days.
  static const masteredIntervalDays = 3;

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
    final scored = results.where((r) => !r.isRetry).toList();
    final correct = scored.where((r) => r.isCorrect).length;
    // XP is for first completion only, so replaying a lesson cannot farm it.
    final xpEarned =
        (previous?.isCompleted ?? false) ? 0 : correct * xpPerLessonAnswer;

    final progress = {
      ...profile.lessonProgress,
      lesson.id: (previous ?? const LessonProgress.started())
          .completedWith(correct: correct, total: scored.length),
    };

    final answered = _recordAnswers(profile, scored, curriculum, now);
    final recallId = 'lesson-${lesson.id}';
    final hasRecall = answered.reviewItems.any((i) => i.id == recallId);
    var updated = answered.copyWith(
      lessonProgress: progress,
      reviewItems: hasRecall
          ? answered.reviewItems
          : _upsertReviews(answered.reviewItems, [
              ReviewItem(
                id: recallId,
                label: lesson.title,
                kind: ReviewItem.lessonRecallKind,
                dueAt: now.add(mistakeReviewDelay),
              ),
            ]),
      xp: profile.xp + xpEarned,
    );

    final earned = path.earnedLevel(updated, curriculum);
    final leveledUp = earned.index > updated.currentLevel.index;
    if (leveledUp) updated = updated.copyWith(currentLevel: earned);

    return (
      profile: updated.copyWith(
        currentLessonId: path.nextLesson(updated, curriculum)?.id,
      ),
      xpEarned: xpEarned,
      leveledUpTo: leveledUp ? earned : null,
    );
  }

  /// Applies a practice or review session. Besides statistics, it reschedules
  /// the reviews the answers speak to: a missed exercise comes back soon, one
  /// answered correctly is spaced further out (and retired once mastered).
  ProgressUpdate completePractice(
    LearningProfile profile,
    Curriculum curriculum,
    List<ExerciseResult> results, {
    required DateTime now,
  }) {
    final scored = results.where((r) => !r.isRetry).toList();
    final xpEarned =
        scored.where((r) => r.isCorrect).length * xpPerPracticeAnswer;
    final updated = _recordAnswers(profile, scored, curriculum, now);
    return (
      profile: updated.copyWith(xp: profile.xp + xpEarned),
      xpEarned: xpEarned,
      leveledUpTo: null,
    );
  }

  /// Applies a flashcard session: reschedules each card, counts new cards
  /// against the day's allowance, and credits XP and the streak.
  ProgressUpdate completeFlashcards(
    LearningProfile profile,
    List<CardReview> reviews, {
    required DateTime now,
  }) {
    final states = {...profile.flashcards.states};
    final today = dayKey(now);
    var newToday =
        profile.flashcards.day == today ? profile.flashcards.newToday : 0;
    final counted = <String>{};
    var xp = 0;
    var scores = profile.scores;
    var vocabulary =
        profile.areaStats[SkillArea.vocabulary.name] ?? const SkillStat();

    for (final review in reviews) {
      final id = review.card.item.id;
      // A card may be asked twice in a session; it is only "new" once.
      if (review.card.isNew && counted.add(id)) newToday++;
      states[id] = cards.review(states[id], review.rating, now);

      final recalled = review.rating.recalled;
      xp += recalled ? xpPerRecalledCard : xpPerForgottenCard;
      vocabulary = vocabulary.recorded(isCorrect: recalled);
      scores = scores.recordOutcome(SkillArea.vocabulary, correct: recalled);
    }

    final updated = registerStudyDay(
      profile.copyWith(
        flashcards: FlashcardProgress(
          states: states,
          day: today,
          newToday: newToday,
        ),
        areaStats: {
          ...profile.areaStats,
          SkillArea.vocabulary.name: vocabulary,
        },
        scores: scores,
        xp: profile.xp + xp,
      ),
      now,
    );
    return (profile: updated, xpEarned: xp, leveledUpTo: null);
  }

  /// Applies a finished mini-game. Answers feed the same skill statistics as
  /// lessons (so games steer the adaptive plan), but a game question is not a
  /// curriculum exercise, so it never creates review items or exercise records.
  ProgressUpdate completeGame(
    LearningProfile profile,
    GameOutcome outcome, {
    required DateTime now,
  }) {
    final skillStats = {...profile.skillStats};
    final kindStats = {...profile.kindStats};
    final areaStats = {...profile.areaStats};
    var scores = profile.scores;
    for (final result in outcome.results) {
      final exercise = result.exercise;
      for (final skill in exercise.skills) {
        skillStats[skill] = (skillStats[skill] ?? const SkillStat())
            .recorded(isCorrect: result.isCorrect);
      }
      kindStats[exercise.kind.name] =
          (kindStats[exercise.kind.name] ?? const SkillStat())
              .recorded(isCorrect: result.isCorrect);
      areaStats[exercise.area.name] =
          (areaStats[exercise.area.name] ?? const SkillStat())
              .recorded(isCorrect: result.isCorrect);
      scores = scores.recordOutcome(exercise.area, correct: result.isCorrect);
    }

    final game = outcome.game.name;
    final gamification = profile.gamification;
    final best = gamification.gameBest[game] ?? 0;
    final updated = registerStudyDay(
      profile.copyWith(
        skillStats: skillStats,
        kindStats: kindStats,
        areaStats: areaStats,
        scores: scores,
        xp: profile.xp + outcome.xp,
        gamification: gamification.copyWith(
          gamesPlayed: gamification.gamesPlayed + 1,
          gameBest: {
            ...gamification.gameBest,
            game: outcome.score > best ? outcome.score : best,
          },
        ),
      ),
      now,
    );
    return (profile: updated, xpEarned: outcome.xp, leveledUpTo: null);
  }

  /// Skill ids the learner is struggling with, weakest first.
  List<String> weakSkills(LearningProfile profile, {int limit = 3}) =>
      weakSkillsOf(profile, limit: limit);

  /// The same, without needing a tracker instance.
  static List<String> weakSkillsOf(LearningProfile profile, {int limit = 3}) {
    final weak = profile.skillStats.entries
        .where((e) =>
            e.value.attempts >= minAttemptsForWeakness &&
            e.value.accuracy < weakAccuracy)
        .toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));
    return [for (final e in weak.take(limit)) e.key];
  }

  /// [scored] must already exclude retries.
  LearningProfile _recordAnswers(
    LearningProfile profile,
    List<ExerciseResult> scored,
    Curriculum curriculum,
    DateTime now,
  ) {
    final skillStats = {...profile.skillStats};
    final exerciseStats = {...profile.exerciseStats};
    final kindStats = {...profile.kindStats};
    final areaStats = {...profile.areaStats};
    var scores = profile.scores;
    final mistakes = [...profile.recentMistakes];
    final newMistakeReviews = <ReviewItem>[];

    for (final result in scored) {
      final exercise = result.exercise;
      for (final skill in exercise.skills) {
        skillStats[skill] = (skillStats[skill] ?? const SkillStat())
            .recorded(isCorrect: result.isCorrect);
      }
      kindStats[exercise.kind.name] =
          (kindStats[exercise.kind.name] ?? const SkillStat())
              .recorded(isCorrect: result.isCorrect);
      areaStats[exercise.area.name] =
          (areaStats[exercise.area.name] ?? const SkillStat())
              .recorded(isCorrect: result.isCorrect);
      exerciseStats[exercise.id] = (exerciseStats[exercise.id] ??
              ExerciseStat(attempts: 0, correct: 0, lastAnsweredAt: now))
          .recorded(isCorrect: result.isCorrect, at: now);
      scores = scores.recordOutcome(exercise.area, correct: result.isCorrect);
      if (result.isCorrect) continue;

      final entry = _mistakeEntry(exercise);
      mistakes
        ..remove(entry)
        ..add(entry);
      newMistakeReviews.add(ReviewItem(
        id: 'exercise-${exercise.id}',
        label: exercise.prompt,
        kind: ReviewItem.mistakeKind,
        dueAt: now.add(mistakeReviewDelay),
      ));
    }

    final overflow = mistakes.length - maxRecentMistakes;
    final reviews = _upsertReviews(
      _rescheduleAnswered(profile.reviewItems, scored, curriculum, now),
      newMistakeReviews,
    );
    return registerStudyDay(
      profile.copyWith(
        skillStats: skillStats,
        exerciseStats: exerciseStats,
        kindStats: kindStats,
        areaStats: areaStats,
        scores: scores,
        recentMistakes: overflow > 0 ? mistakes.sublist(overflow) : mistakes,
        reviewItems: reviews,
      ),
      now,
    );
  }

  /// Reschedules existing reviews touched by [scored]:
  /// - a correctly answered missed exercise is spaced out, or retired once it
  ///   has already been answered correctly after a multi-day gap;
  /// - a lesson-recall item is rated from accuracy on that lesson's exercises.
  /// Wrong answers are handled by the caller, which re-adds the mistake.
  List<ReviewItem> _rescheduleAnswered(
    List<ReviewItem> existing,
    List<ExerciseResult> scored,
    Curriculum curriculum,
    DateTime now,
  ) {
    if (existing.isEmpty || scored.isEmpty) return existing;

    final correctByLesson = <String, int>{};
    final totalByLesson = <String, int>{};
    final correctIds = <String>{};
    for (final result in scored) {
      final lessonId = curriculum.lessonOfExercise(result.exercise.id)?.id;
      if (lessonId != null) {
        totalByLesson[lessonId] = (totalByLesson[lessonId] ?? 0) + 1;
        if (result.isCorrect) {
          correctByLesson[lessonId] = (correctByLesson[lessonId] ?? 0) + 1;
        }
      }
      if (result.isCorrect) correctIds.add(result.exercise.id);
    }

    final next = <ReviewItem>[];
    for (final item in existing) {
      if (item.id.startsWith('exercise-')) {
        final exerciseId = item.id.substring('exercise-'.length);
        if (!correctIds.contains(exerciseId)) {
          next.add(item);
        } else if (item.intervalDays < masteredIntervalDays) {
          next.add(scheduler.schedule(item, ReviewRating.good, now: now));
        } // else: mastered, dropped from the queue.
      } else if (item.id.startsWith('lesson-')) {
        final lessonId = item.id.substring('lesson-'.length);
        final total = totalByLesson[lessonId] ?? 0;
        if (total == 0) {
          next.add(item);
          continue;
        }
        final accuracy = (correctByLesson[lessonId] ?? 0) / total;
        final rating = accuracy >= .8
            ? ReviewRating.good
            : accuracy >= .5
                ? ReviewRating.hard
                : ReviewRating.again;
        next.add(scheduler.schedule(item, rating, now: now));
      } else {
        next.add(item);
      }
    }
    return next;
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

  /// Counts today as a study day: keeps or extends the streak.
  LearningProfile registerStudyDay(LearningProfile profile, DateTime now) {
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
