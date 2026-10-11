import 'dart:math' as math;

import '../models/curriculum.dart';
import '../models/learning_models.dart';
import 'progress_tracker.dart';

/// A recommended lesson and why it was chosen, so the app can show reasons in
/// plain language instead of a mysterious "next".
class PathChoice {
  const PathChoice(this.lesson, this.reasons);

  final Lesson lesson;
  final List<String> reasons;
}

/// Decides which lesson comes next and when a learner has earned a higher
/// level. Deterministic and explainable.
///
/// Personalisation works inside the curriculum's own structure rather than
/// against it. Prerequisites (`requires`) always hold, and a level is finished
/// before the next begins; within what is available the lesson is chosen by the
/// learner's goal, topics and weak skills.
class LearningPath {
  const LearningPath();

  /// Accuracy a level's lessons must average before moving up.
  static const promotionAccuracy = .7;

  // Weights of the personalisation score. Earlier lessons get a head start that
  // grows more slowly the further down the list (logarithmic), so the next few
  // lessons keep their order while a strong signal (a goal match, a weak skill)
  // can still reach further ahead.
  static const _goalMatch = 3.0;
  static const _examFamilyMatch = 2.0;
  static const _topicMatch = .6;
  static const _maxTopicMatches = 2;
  static const _weakSkillMatch = 2.5;
  static const _maxWeakMatches = 2;
  static const _focusMatch = .5;
  static const _sameUnit = .8;
  static const _earlierFirst = .8;

  /// Whether [lesson] counts for this learner. Exam preparation lessons count
  /// only for learners aiming at that exam; everyone can still open them.
  bool isRelevant(Lesson lesson, LearningGoal goal) =>
      lesson.exam == null || lesson.exam == goal.exam;

  /// The lesson to recommend next, in this order:
  ///
  /// 1. the best-matching unfinished, available lesson at the learner's own
  ///    level (levels below were skipped by choosing this one);
  /// 2. if that level is finished but shaky (average best accuracy under
  ///    [promotionAccuracy]), its weakest lesson, so it is revisited first;
  /// 3. the first unfinished lesson at a higher level;
  /// 4. the first unfinished lesson anywhere, and finally the last lesson.
  Lesson? nextLesson(LearningProfile profile, Curriculum curriculum) =>
      choose(profile, curriculum)?.lesson;

  PathChoice? choose(LearningProfile profile, Curriculum curriculum) {
    if (curriculum.isEmpty) return null;

    final level = profile.currentLevel;
    final atLevel = [
      for (final lesson in curriculum.lessonsAt(level))
        if (isRelevant(lesson, profile.goal)) lesson,
    ];
    final unfinished = [
      for (final lesson in atLevel)
        if (!profile.isLessonCompleted(lesson.id)) lesson,
    ];

    if (unfinished.isNotEmpty) {
      final available = [
        for (final lesson in unfinished)
          if (_prerequisitesMet(lesson, profile, curriculum)) lesson,
      ];
      // A broken prerequisite chain must never leave a learner stuck.
      return _best(
        available.isEmpty ? unfinished : available,
        profile,
        curriculum,
      );
    }

    final weakest = _weakestAtLevel(profile, curriculum);
    if (weakest != null && !_meetsPromotionBar(profile, curriculum)) {
      return PathChoice(weakest, const [
        'Strengthen this level before moving on: this was your weakest lesson.',
      ]);
    }

    for (final lesson in curriculum.lessons) {
      if (lesson.level.index > level.index &&
          isRelevant(lesson, profile.goal) &&
          !profile.isLessonCompleted(lesson.id)) {
        return PathChoice(lesson, const ['The next step up from your level.']);
      }
    }

    final fallback = curriculum.firstIncomplete(profile.isLessonCompleted);
    return fallback == null
        ? null
        : PathChoice(fallback, const ['The next lesson in the course.']);
  }

  /// The level the learner has earned, which is [LearningProfile.currentLevel]
  /// unless every relevant lesson there is done with good accuracy and a later
  /// level has lessons to move on to.
  CefrLevel earnedLevel(LearningProfile profile, Curriculum curriculum) {
    final current = profile.currentLevel;
    final atLevel = _relevantAtLevel(profile, curriculum);
    if (atLevel.isEmpty ||
        !atLevel.every((l) => profile.isLessonCompleted(l.id)) ||
        !_meetsPromotionBar(profile, curriculum)) {
      return current;
    }
    for (final level in CefrLevel.values) {
      if (level.index <= current.index) continue;
      final next = curriculum.lessonsAt(level);
      if (next.any((lesson) => isRelevant(lesson, profile.goal))) return level;
    }
    return current;
  }

  // ---------------------------------------------------------------- scoring

  PathChoice _best(
    List<Lesson> candidates,
    LearningProfile profile,
    Curriculum curriculum,
  ) {
    final weak = ProgressTracker.weakSkillsOf(profile).toSet();
    final interests = {...profile.preferredTopics, ...profile.goal.topics};
    final focus = profile.focusSkills.map((s) => s.toLowerCase()).toSet();
    final lastUnit = _lastCompletedUnit(profile, curriculum);

    PathChoice? best;
    var bestScore = double.negativeInfinity;
    for (var rank = 0; rank < candidates.length; rank++) {
      final lesson = candidates[rank];
      final reasons = <String>[];
      var score = -_earlierFirst * math.log(1 + rank);

      if (lesson.goals.contains(profile.goal)) {
        score += _goalMatch;
        reasons.add('Matches your goal: ${profile.goal.label}.');
      } else if (lesson.exam != null && lesson.exam == profile.goal.exam) {
        score += _examFamilyMatch;
        reasons.add('Prepares you for ${profile.goal.label}.');
      }

      final topics = lesson.topics.where(interests.contains).toList();
      if (topics.isNotEmpty) {
        final counted = topics.length.clamp(0, _maxTopicMatches);
        score += _topicMatch * counted;
        reasons.add('Fits your interests: ${topics.take(2).join(', ')}.');
      }

      final trained = {
        for (final exercise in lesson.exercises) ...exercise.skills,
      };
      final remedies = trained.where(weak.contains).toList();
      if (remedies.isNotEmpty) {
        score += _weakSkillMatch * remedies.length.clamp(0, _maxWeakMatches);
        reasons.add(
          'Builds ${skillLabel(remedies.first).toLowerCase()}, which you find hard.',
        );
      }

      final areas = {
        for (final e in lesson.exercises) e.area.label.toLowerCase()
      };
      if (areas.any(focus.contains)) {
        score += _focusMatch;
        reasons.add('Trains a skill you chose to focus on.');
      }

      if (lastUnit != null && lesson.unit == lastUnit) {
        score += _sameUnit;
        reasons.add('Continues the unit you are in.');
      }

      if (score > bestScore) {
        bestScore = score;
        best = PathChoice(lesson, reasons);
      }
    }
    return best!;
  }

  /// The unit of the furthest lesson already completed at the learner's level,
  /// so the next lesson can prefer staying in the same unit.
  String? _lastCompletedUnit(LearningProfile profile, Curriculum curriculum) {
    final atLevel = curriculum.lessonsAt(profile.currentLevel);
    for (var i = atLevel.length - 1; i >= 0; i--) {
      if (profile.isLessonCompleted(atLevel[i].id)) return atLevel[i].unit;
    }
    return null;
  }

  bool _prerequisitesMet(
    Lesson lesson,
    LearningProfile profile,
    Curriculum curriculum,
  ) {
    for (final id in lesson.requires) {
      if (profile.isLessonCompleted(id)) continue;
      final required = curriculum.lessonById(id);
      // Anything below the learner's level was skipped by self-placement and
      // is assumed known.
      if (required != null &&
          required.level.index < profile.currentLevel.index) {
        continue;
      }
      return false;
    }
    return true;
  }

  List<Lesson> _relevantAtLevel(
          LearningProfile profile, Curriculum curriculum) =>
      [
        for (final lesson in curriculum.lessonsAt(profile.currentLevel))
          if (isRelevant(lesson, profile.goal)) lesson,
      ];

  bool _meetsPromotionBar(LearningProfile profile, Curriculum curriculum) {
    final atLevel = _relevantAtLevel(profile, curriculum);
    if (atLevel.isEmpty) return true;
    final total = atLevel.fold<double>(
      0,
      (sum, l) => sum + (profile.lessonProgress[l.id]?.bestAccuracy ?? 0),
    );
    return total / atLevel.length >= promotionAccuracy;
  }

  Lesson? _weakestAtLevel(LearningProfile profile, Curriculum curriculum) {
    final atLevel = _relevantAtLevel(profile, curriculum);
    if (atLevel.isEmpty ||
        !atLevel.every((l) => profile.isLessonCompleted(l.id))) {
      return null;
    }
    return atLevel.reduce((a, b) {
      final accuracyA = profile.lessonProgress[a.id]?.bestAccuracy ?? 0;
      final accuracyB = profile.lessonProgress[b.id]?.bestAccuracy ?? 0;
      return accuracyB < accuracyA ? b : a;
    });
  }
}
