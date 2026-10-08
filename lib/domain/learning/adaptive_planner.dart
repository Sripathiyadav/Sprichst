import 'dart:math' as math;

import '../models/curriculum.dart';
import '../models/learning_models.dart';
import 'learner_insights.dart';
import 'learning_path.dart';
import 'progress_tracker.dart';

enum PlanKind { review, practice, lesson }

/// The single most useful thing for the learner to do now, with the reason.
class DailyPlan {
  const DailyPlan({
    required this.kind,
    required this.title,
    required this.reason,
    this.skillIds = const [],
    this.lesson,
  });

  final PlanKind kind;
  final String title;
  final String reason;

  /// Skills a [PlanKind.practice] plan focuses on.
  final List<String> skillIds;

  /// The lesson a [PlanKind.lesson] plan opens.
  final Lesson? lesson;
}

/// Chooses what to study next from the learner's history. Every decision is a
/// deterministic function of that history, so it is testable and explainable;
/// no model is involved.
class AdaptivePlanner {
  const AdaptivePlanner({
    this.tracker = const ProgressTracker(),
    this.path = const LearningPath(),
  });

  final ProgressTracker tracker;
  final LearningPath path;

  static const defaultSessionLength = 6;

  /// Skills a never-seen skill is assumed to need: a little above "mastered".
  static const _unknownSkillWeakness = .3;

  /// Lessons the learner may be tested on: those they have started or finished.
  /// Practising material that was never taught would only produce mistakes.
  Set<String> unlockedLessonIds(LearningProfile profile) =>
      profile.lessonProgress.keys.toSet();

  /// Skills the learner can practise now: those trained by a started lesson.
  List<String> practisableSkills(
      LearningProfile profile, Curriculum curriculum) {
    final skills = <String>{};
    for (final id in unlockedLessonIds(profile)) {
      final lesson = curriculum.lessonById(id);
      if (lesson == null) continue;
      for (final exercise in lesson.exercises) {
        skills.addAll(exercise.skills);
      }
    }
    return skills.toList()..sort();
  }

  DailyPlan? plan(
    LearningProfile profile,
    Curriculum curriculum, {
    required DateTime now,
  }) {
    if (curriculum.isEmpty) return null;

    final due = profile.reviewItems.where((i) => !i.dueAt.isAfter(now)).length;
    if (due > 0 && _hasPractisable(profile, curriculum)) {
      return DailyPlan(
        kind: PlanKind.review,
        title: 'Review $due ${due == 1 ? 'item' : 'items'}',
        reason: 'Bring back what you missed before it fades.',
      );
    }

    final weak = tracker.weakSkills(profile);
    if (weak.isNotEmpty && _hasPractisable(profile, curriculum)) {
      return DailyPlan(
        kind: PlanKind.practice,
        title: 'Strengthen ${skillLabel(weak.first)}',
        reason: 'Your recent answers show this needs more practice.',
        skillIds: weak,
      );
    }

    final choice = path.choose(profile, curriculum);
    if (choice == null) return null;
    final next = choice.lesson;
    final started = profile.lessonProgress.containsKey(next.id);
    return DailyPlan(
      kind: PlanKind.lesson,
      title: '${started ? 'Continue' : 'Start'} ${next.title}',
      // Why this lesson, in the learner's own terms; the objective otherwise.
      reason: choice.reasons.isEmpty ? next.objective : choice.reasons.first,
      lesson: next,
    );
  }

  bool _hasPractisable(LearningProfile profile, Curriculum curriculum) =>
      unlockedLessonIds(profile).any(
        (id) => curriculum.lessonById(id)?.exercises.isNotEmpty ?? false,
      );

  /// Builds a practice session of up to [limit] exercises.
  ///
  /// Each unlocked exercise is scored on how much the learner needs it (due
  /// reviews, weak skills, past mistakes, novelty, time since last seen) and how
  /// well its difficulty fits their level in that skill. The best are chosen
  /// greedily with a penalty for repeating a skill, so a session mixes skills,
  /// then ordered easiest-first as a warm-up. O(limit × candidates).
  List<Exercise> buildSession(
    LearningProfile profile,
    Curriculum curriculum, {
    required DateTime now,
    Iterable<String>? skillIds,
    int limit = defaultSessionLength,
  }) {
    final unlocked = unlockedLessonIds(profile);
    final focus = skillIds?.toSet();
    final dueIds = _dueExerciseIds(profile, curriculum, now);
    final pendingMistakes = {
      for (final item in profile.reviewItems)
        if (item.kind == ReviewItem.mistakeKind) item.id,
    };

    final candidates = <_Scored>[];
    var order = 0;
    for (final lesson in curriculum.lessons) {
      if (!unlocked.contains(lesson.id)) continue;
      for (final exercise in lesson.exercises) {
        order++;
        if (focus != null && !exercise.skills.any(focus.contains)) continue;
        candidates.add(_Scored(
          exercise,
          order,
          _score(profile, exercise, now,
              isDue: dueIds.contains(exercise.id),
              hasPendingMistake:
                  pendingMistakes.contains('exercise-${exercise.id}')),
        ));
      }
    }

    final picked = <_Scored>[];
    final skillUse = <String, int>{};
    while (picked.length < limit && candidates.isNotEmpty) {
      var bestIndex = 0;
      var bestValue = double.negativeInfinity;
      for (var i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        final value = candidate.score -
            _repeatPenalty * (skillUse[candidate.exercise.skills.first] ?? 0);
        if (value > bestValue ||
            (value == bestValue &&
                candidate.order < candidates[bestIndex].order)) {
          bestValue = value;
          bestIndex = i;
        }
      }
      final chosen = candidates.removeAt(bestIndex);
      picked.add(chosen);
      final skill = chosen.exercise.skills.first;
      skillUse[skill] = (skillUse[skill] ?? 0) + 1;
    }

    picked.sort((a, b) {
      final byDifficulty =
          a.exercise.difficulty.compareTo(b.exercise.difficulty);
      return byDifficulty != 0 ? byDifficulty : a.order.compareTo(b.order);
    });
    return [for (final p in picked) p.exercise];
  }

  static const _repeatPenalty = .35;

  double _score(
    LearningProfile profile,
    Exercise exercise,
    DateTime now, {
    required bool isDue,
    required bool hasPendingMistake,
  }) {
    final stats = [
      for (final skill in exercise.skills) profile.skillStats[skill],
    ];
    final skillWeakness = stats
        .map((s) => s == null ? _unknownSkillWeakness : 1 - s.accuracy)
        .reduce(math.max);

    final seen = profile.exerciseStats[exercise.id];
    final exerciseWeakness = seen == null ? 0.0 : 1 - seen.accuracy;
    final novelty = seen == null ? 1.0 : 0.0;
    // Something answered a moment ago should not come straight back; the
    // penalty fades over a day. Missed exercises return through due reviews.
    final justSeen = seen == null
        ? 0.0
        : 1 - math.min(1.0, now.difference(seen.lastAnsweredAt).inHours / 24);

    return 2.0 * (isDue ? 1 : 0) +
        1.2 * skillWeakness +
        .8 * exerciseWeakness +
        .5 * (hasPendingMistake ? 1 : 0) +
        .6 * novelty -
        .8 * justSeen +
        .6 * LearnerInsights.need(profile, exercise.kind) +
        .5 * _difficultyFit(exercise, stats.first);
  }

  /// 1 when the exercise's difficulty equals the learner's target for the
  /// skill, falling toward 0 as it moves away.
  double _difficultyFit(Exercise exercise, SkillStat? stat) =>
      1 - (exercise.difficulty - targetDifficulty(stat)).abs() / 2;

  /// New or struggling skills get easy items; confident ones get harder ones.
  static int targetDifficulty(SkillStat? stat) {
    if (stat == null || stat.attempts < 2) return 1;
    if (stat.accuracy >= .85 && stat.attempts >= 4) return 3;
    return stat.accuracy >= .6 ? 2 : 1;
  }

  /// Exercises behind every review item that is due now: the missed exercise
  /// itself, or, for a lesson recall, up to three of that lesson's exercises,
  /// weakest first.
  Set<String> _dueExerciseIds(
    LearningProfile profile,
    Curriculum curriculum,
    DateTime now,
  ) {
    final ids = <String>{};
    for (final item in profile.reviewItems) {
      if (item.dueAt.isAfter(now)) continue;
      if (item.id.startsWith('exercise-')) {
        ids.add(item.id.substring('exercise-'.length));
      } else if (item.id.startsWith('lesson-')) {
        final lesson =
            curriculum.lessonById(item.id.substring('lesson-'.length));
        if (lesson == null) continue;
        final byWeakness = [...lesson.exercises]..sort((a, b) =>
            (profile.exerciseStats[a.id]?.accuracy ?? .5)
                .compareTo(profile.exerciseStats[b.id]?.accuracy ?? .5));
        ids.addAll(byWeakness.take(3).map((e) => e.id));
      }
    }
    return ids;
  }
}

class _Scored {
  const _Scored(this.exercise, this.order, this.score);

  final Exercise exercise;
  final int order;
  final double score;
}
