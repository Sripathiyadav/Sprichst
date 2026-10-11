import 'dart:convert';

import '../domain/models/dialogue_models.dart';
import '../domain/models/learning_models.dart';

/// Parses and validates the bundled course (`curriculum/course.json`).
///
/// Validation lives here, not only in the content script, so a bad edit fails
/// loudly with the offending lesson and exercise rather than corrupting a
/// learner's session.
abstract final class CurriculumParser {
  static const assetPath = 'curriculum/course.json';

  static List<Lesson> parse(String source) {
    final root = _root(source);
    final lessons = [
      for (final raw in _list(root, 'lessons', 'course'))
        _lesson(_object(raw, 'lesson')),
    ];

    _requireUnique(lessons.map((l) => l.id), 'lesson');
    _requireUnique(
      [for (final l in lessons) ...l.exercises.map((e) => e.id)],
      'exercise',
    );
    _requireUnique(
      [for (final l in lessons) ...l.vocabulary.map((v) => v.id)],
      'vocabulary item',
    );

    // Prerequisites must name real, earlier lessons, which also rules out cycles.
    final seen = <String>{};
    for (final lesson in lessons) {
      for (final required in lesson.requires) {
        if (!seen.contains(required)) {
          throw FormatException(
              'lesson "${lesson.id}" requires "$required", which is not an earlier lesson.');
        }
      }
      seen.add(lesson.id);
    }
    return lessons;
  }

  /// The conversations used by the dialogue game; an absent list means none.
  static List<Dialogue> parseDialogues(String source) {
    final root = _root(source);
    if (!root.containsKey('dialogues')) return const [];
    final dialogues = [
      for (final raw in _list(root, 'dialogues', 'course'))
        _dialogue(_object(raw, 'dialogue')),
    ];
    _requireUnique(dialogues.map((d) => d.id), 'dialogue');
    return dialogues;
  }

  static Map<String, dynamic> _root(String source) {
    final root = jsonDecode(source);
    if (root is! Map) {
      throw const FormatException('The course must be a JSON object.');
    }
    return Map<String, dynamic>.from(root);
  }

  // ---------------------------------------------------------------- lessons

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

    final exam = json['exam'];
    if (exam != null && exam != 'goethe' && exam != 'testdaf') {
      throw FormatException('$context: "exam" must be goethe or testdaf.');
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
      vocabulary: [
        if (json.containsKey('vocabulary'))
          for (final raw in _list(json, 'vocabulary', context))
            _vocab(_object(raw, 'vocabulary item in $context'), id, context),
      ],
      topics: json.containsKey('topics')
          ? _strings(json, 'topics', context)
          : const [],
      goals: [
        if (json.containsKey('goals'))
          for (final name in _strings(json, 'goals', context))
            _enumValue(LearningGoal.values, name, 'goals', context),
      ],
      requires: json.containsKey('requires')
          ? _strings(json, 'requires', context)
          : const [],
      exam: exam as String?,
    );
  }

  static VocabItem _vocab(
    Map<String, dynamic> json,
    String lessonId,
    String lessonContext,
  ) {
    final german = _string(json, 'de', 'vocabulary in $lessonContext');
    final context = 'vocabulary "$german" in $lessonContext';
    final article = json['article'];
    if (article != null && !{'der', 'die', 'das'}.contains(article)) {
      throw FormatException('$context: "article" must be der, die, or das.');
    }
    return VocabItem(
      id: '$lessonId/${_slug(german)}',
      german: german,
      english: _string(json, 'en', context),
      article: article as String?,
      example: json['example'] as String?,
      exampleEnglish: json['exampleEn'] as String?,
    );
  }

  /// Lower-case ASCII slug that keeps ids stable and readable.
  static String _slug(String text) => text
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  // -------------------------------------------------------------- exercises

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
      context: json['context'] as String?,
      audioText: json['audioText'] as String?,
      examPart: json['examPart'] as String?,
      gaps: [
        if (json.containsKey('gaps'))
          for (final raw in _list(json, 'gaps', context))
            _gap(_object(raw, 'gap in $context'), context),
      ],
      brief: json.containsKey('brief')
          ? _brief(_object(json['brief'], 'brief in $context'), context)
          : null,
      difficulty:
          json.containsKey('difficulty') ? _difficulty(json, context) : null,
    );

    if (exercise.skills.isEmpty) {
      throw FormatException('$context needs at least one skill.');
    }
    switch (exercise.kind) {
      case ExerciseKind.multipleChoice:
        _requireAnswerInOptions(exercise, context);
      case ExerciseKind.listening:
        if ((exercise.audioText ?? '').trim().isEmpty) {
          throw FormatException('$context: a listening task needs audioText.');
        }
        _requireAnswerInOptions(exercise, context);
      case ExerciseKind.wordOrder:
        final bank = [...exercise.options]..sort();
        for (final answer in exercise.acceptedAnswers) {
          if (!_sameItems(bank, answer.split(' '))) {
            throw FormatException(
                '$context: "$answer" must use exactly the words in the word bank.');
          }
        }
      case ExerciseKind.cloze:
        if (exercise.gaps.isEmpty) {
          throw FormatException('$context: a cloze needs at least one gap.');
        }
        final text = exercise.context ?? '';
        for (var n = 1; n <= exercise.gaps.length; n++) {
          if (!text.contains('{$n}')) {
            throw FormatException(
                '$context: the passage must contain the marker {$n}.');
          }
        }
      case ExerciseKind.writing:
        final brief = exercise.brief;
        if (brief == null) {
          throw FormatException('$context: a writing task needs a brief.');
        }
        if (brief.minWords < 1) {
          throw FormatException('$context: minWords must be positive.');
        }
        if (brief.points.isEmpty) {
          throw FormatException(
              '$context: a writing task needs at least one content point.');
        }
      case ExerciseKind.fillBlank ||
            ExerciseKind.translation ||
            ExerciseKind.speaking:
        break;
    }
    return exercise;
  }

  static void _requireAnswerInOptions(Exercise exercise, String context) {
    if (!exercise.options.contains(exercise.answer)) {
      throw FormatException('$context: the answer must be one of the options.');
    }
  }

  static ClozeGap _gap(Map<String, dynamic> json, String context) {
    final options = _strings(json, 'options', context);
    final answer = _string(json, 'answer', context);
    if (!options.contains(answer)) {
      throw FormatException(
          '$context: a gap answer must be one of its options.');
    }
    return ClozeGap(options: options, answer: answer);
  }

  static WritingBrief _brief(Map<String, dynamic> json, String context) {
    return WritingBrief(
      minWords: _int(json, 'minWords', context),
      register: _enum(WritingRegister.values, json, 'register', context),
      points: [
        for (final raw in _list(json, 'points', context))
          ContentPoint(
            label: _string(_object(raw, 'point in $context'), 'label', context),
            keywords: _strings(
                _object(raw, 'point in $context'), 'keywords', context),
          ),
      ],
    );
  }

  static bool _sameItems(List<String> sortedBank, List<String> words) {
    final sorted = [...words]..sort();
    if (sorted.length != sortedBank.length) return false;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i] != sortedBank[i]) return false;
    }
    return true;
  }

  // -------------------------------------------------------------- dialogues

  static Dialogue _dialogue(Map<String, dynamic> json) {
    final id = _string(json, 'id', 'dialogue');
    final context = 'dialogue "$id"';
    final turns = [
      for (final raw in _list(json, 'turns', context))
        _turn(_object(raw, 'turn in $context'), context),
    ];
    if (turns.isEmpty || !turns.any((t) => t.isLearner)) {
      throw FormatException('$context needs at least one learner turn.');
    }
    return Dialogue(
      id: id,
      title: _string(json, 'title', context),
      level: _enum(CefrLevel.values, json, 'level', context),
      topics: json.containsKey('topics')
          ? _strings(json, 'topics', context)
          : const [],
      turns: turns,
    );
  }

  static DialogueTurn _turn(Map<String, dynamic> json, String context) {
    if (json.containsKey('options')) {
      final options = _strings(json, 'options', context);
      final answer = _string(json, 'answer', context);
      if (!options.contains(answer)) {
        throw FormatException(
            '$context: a learner turn answer must be one of its options.');
      }
      return DialogueTurn.learner(
        intent: _string(json, 'intent', context),
        options: options,
        answer: answer,
      );
    }
    return DialogueTurn.partner(
      text: _string(json, 'text', context),
      english: json['english'] as String?,
    );
  }

  // ---------------------------------------------------------------- helpers

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

  static int _difficulty(Map<String, dynamic> json, String context) {
    final value = _int(json, 'difficulty', context);
    if (value < 1 || value > 3) {
      throw FormatException('$context: "difficulty" must be 1, 2, or 3.');
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
  ) =>
      _enumValue(values, json[key], key, context);

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? raw,
    String key,
    String context,
  ) {
    final value = values.asNameMap()[raw];
    if (value == null) {
      throw FormatException(
          '$context: "$key" must be one of ${values.map((v) => v.name).join(', ')}.');
    }
    return value;
  }
}
