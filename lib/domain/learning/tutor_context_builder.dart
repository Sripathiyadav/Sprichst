import '../models/curriculum.dart';
import '../models/learning_models.dart';
import 'progress_tracker.dart';

/// Builds the learning state the AI tutor receives. Everything is derived from
/// the learner's history, so the tutor reinforces what was actually taught and
/// missed rather than guessing from a level label.
class TutorContextBuilder {
  const TutorContextBuilder({this.tracker = const ProgressTracker()});

  final ProgressTracker tracker;

  /// The gateway accepts at most this many vocabulary items.
  static const maxVocabulary = 30;

  TutorContext build(
    LearningProfile profile,
    Curriculum curriculum, {
    Lesson? currentLesson,
  }) {
    final weak = tracker.weakSkills(profile).map(skillLabel).toList();
    return TutorContext(
      level: profile.currentLevel.label,
      unit: currentLesson?.unit,
      lesson: currentLesson?.title,
      weakSkills: weak.isNotEmpty ? weak : _lowestScoringAreas(profile),
      knownVocabulary: _knownVocabulary(profile, curriculum),
      recentMistakes: profile.recentMistakes,
    );
  }

  /// With no evidence yet, hint at the broad areas with the lowest scores.
  List<String> _lowestScoringAreas(LearningProfile profile) {
    final entries = profile.scores.entries.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final entry in entries.take(2)) entry.key];
  }

  /// Vocabulary from completed lessons, most recently taught first, so the
  /// tutor leans on what is freshest.
  List<String> _knownVocabulary(
      LearningProfile profile, Curriculum curriculum) {
    final words = <String>{};
    for (final lesson in curriculum.lessons.reversed) {
      if (!profile.isLessonCompleted(lesson.id)) continue;
      words.addAll(lesson.vocabulary.map((word) => word.display));
      if (words.length >= maxVocabulary) break;
    }
    return words.take(maxVocabulary).toList();
  }
}
