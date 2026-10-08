import 'learning_models.dart';

/// A themed group of consecutive lessons at one CEFR level.
class CurriculumUnit {
  const CurriculumUnit({
    required this.level,
    required this.title,
    required this.lessons,
  });

  final CefrLevel level;
  final String title;
  final List<Lesson> lessons;
}

/// The Course → Level → Unit → Lesson → Exercise hierarchy, indexed once so
/// every lookup the UI and tracker need is O(1) or linear in the result.
class Curriculum {
  Curriculum(Iterable<Lesson> source)
      : lessons = List.unmodifiable(source),
        _indexById = {},
        _lessonsByLevel = {},
        _exercisesBySkill = {},
        _exerciseIndex = {},
        _lessonByExercise = {} {
    final unitsByKey = <String, List<Lesson>>{};
    for (var index = 0; index < lessons.length; index++) {
      final lesson = lessons[index];
      _indexById[lesson.id] = index;
      _lessonsByLevel.putIfAbsent(lesson.level, () => []).add(lesson);
      unitsByKey
          .putIfAbsent('${lesson.level.name}|${lesson.unit}', () => [])
          .add(lesson);
      for (final exercise in lesson.exercises) {
        _exerciseIndex[exercise.id] = exercise;
        _lessonByExercise[exercise.id] = lesson;
        for (final skill in exercise.skills) {
          _exercisesBySkill.putIfAbsent(skill, () => []).add(exercise);
        }
      }
    }
    units = List.unmodifiable([
      for (final group in unitsByKey.values)
        CurriculumUnit(
          level: group.first.level,
          title: group.first.unit,
          lessons: List.unmodifiable(group),
        ),
    ]);
  }

  final List<Lesson> lessons;
  late final List<CurriculumUnit> units;
  final Map<String, int> _indexById;
  final Map<CefrLevel, List<Lesson>> _lessonsByLevel;
  final Map<String, List<Exercise>> _exercisesBySkill;
  final Map<String, Exercise> _exerciseIndex;
  final Map<String, Lesson> _lessonByExercise;

  bool get isEmpty => lessons.isEmpty;

  /// Every skill id that at least one exercise trains, in a stable order.
  List<String> get skills => _exercisesBySkill.keys.toList()..sort();

  Lesson? lessonById(String id) {
    final index = _indexById[id];
    return index == null ? null : lessons[index];
  }

  Exercise? exerciseById(String id) => _exerciseIndex[id];

  Lesson? lessonOfExercise(String exerciseId) => _lessonByExercise[exerciseId];

  /// Every exercise, in curriculum order.
  Iterable<Exercise> get exercises => lessons.expand((l) => l.exercises);

  /// The first lesson taught at [level] or any later level, or null when the
  /// course has nothing at or above it.
  Lesson? firstLessonAtOrAbove(CefrLevel level) {
    for (final lesson in lessons) {
      if (lesson.level.index >= level.index) return lesson;
    }
    return null;
  }

  List<Lesson> lessonsAt(CefrLevel level) => _lessonsByLevel[level] ?? const [];

  /// The first lesson, in curriculum order, that [isCompleted] rejects. When
  /// everything is done the last lesson stays current so the learner can revisit
  /// it.
  Lesson? firstIncomplete(bool Function(String lessonId) isCompleted) {
    if (lessons.isEmpty) return null;
    return lessons.firstWhere(
      (lesson) => !isCompleted(lesson.id),
      orElse: () => lessons.last,
    );
  }

  /// Fraction of [level]'s lessons for which [isCompleted] holds; 0 when the
  /// level has no published lessons.
  double levelProgress(CefrLevel level, bool Function(String) isCompleted) {
    final atLevel = lessonsAt(level);
    if (atLevel.isEmpty) return 0;
    return atLevel.where((lesson) => isCompleted(lesson.id)).length /
        atLevel.length;
  }

  /// Up to [limit] distinct exercises for [skillIds], interleaved so that each
  /// skill is represented before any one skill repeats. Runs in
  /// O(limit × skillIds.length).
  List<Exercise> exercisesForSkills(
    Iterable<String> skillIds, {
    int limit = 6,
  }) {
    final pools = [
      for (final skill in skillIds)
        if (_exercisesBySkill[skill] != null) _exercisesBySkill[skill]!,
    ];
    final picked = <Exercise>[];
    final seen = <String>{};
    for (var depth = 0; picked.length < limit; depth++) {
      var anyLeft = false;
      for (final pool in pools) {
        if (depth >= pool.length) continue;
        anyLeft = true;
        final exercise = pool[depth];
        if (seen.add(exercise.id) && picked.length < limit) {
          picked.add(exercise);
        }
      }
      if (!anyLeft) break;
    }
    return picked;
  }
}
