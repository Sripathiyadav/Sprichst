import 'dart:math' as math;

import '../models/curriculum.dart';
import '../models/learning_models.dart';
import 'core_vocabulary.dart';

/// The words a game may use: those from lessons the learner has started first,
/// then the core list to make up the numbers, so games never run dry.
class WordPool {
  const WordPool._();

  /// Nouns (with articles), learner's own words first.
  static List<VocabItem> nouns(
    LearningProfile profile,
    Curriculum curriculum, {
    int minimum = 12,
  }) {
    final own = [
      for (final lesson in curriculum.lessons)
        if (profile.lessonProgress.containsKey(lesson.id))
          ...lesson.vocabulary.where((w) => w.isNoun),
    ];
    return _topUp(own, coreNouns.where((w) => w.isNoun).toList(), minimum);
  }

  /// Words with a meaning to match, nouns or verbs, learner's own first.
  static List<VocabItem> words(
    LearningProfile profile,
    Curriculum curriculum, {
    int minimum = 12,
  }) {
    final own = [
      for (final lesson in curriculum.lessons)
        if (profile.lessonProgress.containsKey(lesson.id)) ...lesson.vocabulary,
    ];
    return _topUp(own, coreNouns, minimum);
  }

  static List<VocabItem> _topUp(
    List<VocabItem> own,
    List<VocabItem> fallback,
    int minimum,
  ) {
    if (own.length >= minimum) return own;
    final have = {for (final w in own) w.german.toLowerCase()};
    return [
      ...own,
      for (final w in fallback)
        if (!have.contains(w.german.toLowerCase())) w,
    ];
  }

  /// A seeded, repeat-free draw of up to [count] items.
  static List<T> draw<T>(List<T> items, int count, math.Random random) {
    final shuffled = [...items]..shuffle(random);
    return shuffled.take(count).toList();
  }
}
