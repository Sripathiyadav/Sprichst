import 'dart:convert';

import '../domain/models/learning_models.dart';

/// Parses and validates `curriculum/course.json`.
///
/// Validation lives here, not only in the content script, so a bad edit fails
/// loudly with the offending lesson and exercise rather than corrupting a
/// learner's session.
abstract final class CurriculumParser {
  static const assetPath = 'curriculum/course.json';

  static List<Lesson> parse(String source) {
    final root = jsonDecode(source);
    if (root is! Map || root['lessons'] is! List) {
      throw const FormatException('Curriculum must contain a "lessons" list.');
    }

    final lessons = [
      for (final raw in root['lessons'] as List)
        _lesson(_object(raw, 'lesson')),
    ];
    _requireUnique(lessons.map((l) => l.id), 'lesson');
    _requireUnique(
      [for (final l in lessons) ...l.exercises.map((e) => e.id)],
      'exercise',
    );
    return lessons;
  }

  static Lesson _lesson(Map<String, dynamic> json) {
    final id = _string(json, 'id', 'lesson');
    final context = 'lesson "$id"';
    final exercises = [
      for (final raw in _list(json, 'exercises', context))
        _exercise(_object(raw, 'exercise in $context'), context),
    ];
    if (exercises.isEmpty) {
      throw FormatException('$context has no exercises.');
    }
    return Lesson(
      id: id,
      level: _enum(CefrLevel.values, json, 'level', context),
      unit: _string(json, 'unit', context),
      title: _string(json, 'title', context),
      durationMinutes: _int(json, 'durationMinutes', context),
      objective: _string(json, 'objective', context),
      introduction: _string(json, 'introduction', context),
      examples: _strings(json, 'examples', context),
      exercises: exercises,
    );
  }

  static Exercise _exercise(Map<String, dynamic> json, String lessonContext) {
    final id = _string(json, 'id', 'exercise in $lessonContext');
    final context = 'exercise "$id"';
    final exercise = Exercise(
      id: id,
      kind: _enum(ExerciseKind.values, json, 'kind', context),
      area: _enum(SkillArea.values, json, 'area', context),
      prompt: _string(json, 'prompt', context),
      options: json.containsKey('options')
          ? _strings(json, 'options', context)
          : const [],
      answer: _string(json, 'answer', context),
      alternatives: json.containsKey('alternatives')
          ? _strings(json, 'alternatives', context)
          : const [],
      explanation: _string(json, 'explanation', context),
      skills: _strings(json, 'skills', context),
    );

    if (exercise.skills.isEmpty) {
      throw FormatException('$context needs at least one skill.');
    }
    switch (exercise.kind) {
      case ExerciseKind.multipleChoice:
        if (!exercise.options.contains(exercise.answer)) {
          throw FormatException(
              '$context: the answer must be one of the options.');
        }
      case ExerciseKind.wordOrder:
        final bank = [...exercise.options]..sort();
        for (final answer in exercise.acceptedAnswers) {
          if (!_sameItems(bank, answer.split(' '))) {
            throw FormatException(
                '$context: "$answer" must use exactly the words in the word bank.');
          }
        }
      case ExerciseKind.fillBlank || ExerciseKind.translation:
        break;
    }
    return exercise;
  }

  static bool _sameItems(List<String> sortedBank, List<String> words) {
    final sorted = [...words]..sort();
    if (sorted.length != sortedBank.length) return false;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i] != sortedBank[i]) return false;
    }
    return true;
  }

  static void _requireUnique(Iterable<String> ids, String what) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) throw FormatException('Duplicate $what id "$id".');
    }
  }

  static Map<String, dynamic> _object(Object? raw, String what) {
    if (raw is! Map) throw FormatException('Expected an object for $what.');
    return Map<String, dynamic>.from(raw);
  }

  static List<dynamic> _list(
      Map<String, dynamic> json, String key, String context) {
    final value = json[key];
    if (value is! List) {
      throw FormatException('$context: "$key" must be a list.');
    }
    return value;
  }

  static List<String> _strings(
      Map<String, dynamic> json, String key, String context) {
    final values = _list(json, key, context);
    if (values.any((v) => v is! String)) {
      throw FormatException('$context: "$key" must contain only text.');
    }
    return List<String>.from(values);
  }

  static String _string(Map<String, dynamic> json, String key, String context) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$context: "$key" must be non-empty text.');
    }
    return value;
  }

  static int _int(Map<String, dynamic> json, String key, String context) {
    final value = json[key];
    if (value is! int) {
      throw FormatException('$context: "$key" must be a whole number.');
    }
    return value;
  }

  static T _enum<T extends Enum>(
    List<T> values,
    Map<String, dynamic> json,
    String key,
    String context,
  ) {
    final value = values.asNameMap()[json[key]];
    if (value == null) {
      throw FormatException(
          '$context: "$key" must be one of ${values.map((v) => v.name).join(', ')}.');
    }
    return value;
  }
}
