import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/speech_matcher.dart';
import 'package:sprichst/domain/learning/writing_assessor.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

/// The response that is correct for [exercise], in the form the UI would send.
String _perfectResponse(Exercise e) => switch (e.kind) {
      ExerciseKind.cloze =>
        e.gaps.map((g) => g.answer).join(ExerciseEvaluator.gapSeparator),
      _ => e.answer,
    };

void main() {
  final lessons = loadCourse();
  final exercises = [for (final l in lessons) ...l.exercises];
  const evaluator = ExerciseEvaluator();

  test('ids are unique across lessons, exercises, and vocabulary', () {
    Set<String> unique(Iterable<String> ids) => ids.toSet();
    expect(unique(lessons.map((l) => l.id)), hasLength(lessons.length));
    expect(unique(exercises.map((e) => e.id)), hasLength(exercises.length));
    final words = [for (final l in lessons) ...l.vocabulary];
    expect(unique(words.map((w) => w.id)), hasLength(words.length));
  });

  test('no word is taught twice across the course', () {
    final seen = <String, String>{};
    for (final lesson in lessons) {
      for (final word in lesson.vocabulary) {
        final key = word.display.toLowerCase();
        expect(seen.containsKey(key), isFalse,
            reason: '"$key" is in ${seen[key]} and ${lesson.id}');
        seen[key] = lesson.id;
      }
    }
  });

  test('every noun card carries its article, and every card is complete', () {
    for (final lesson in lessons) {
      for (final word in lesson.vocabulary) {
        expect(word.english, isNotEmpty, reason: word.id);
        if (word.article != null) {
          expect(['der', 'die', 'das'], contains(word.article),
              reason: word.id);
        }
        // A capitalised word without an article is a noun missing its article.
        final looksLikeNoun = word.german[0].toUpperCase() == word.german[0] &&
            word.german.split(' ').length == 1;
        if (looksLikeNoun && word.article == null) {
          // Allowed exceptions: weekdays handled with articles, adverbs, etc.
          expect(
            const {'Hallo', 'Tschüss', 'Danke', 'Bitte', 'Guten Morgen'}
                .contains(word.german),
            isTrue,
            reason: '${word.id} looks like a noun with no article',
          );
        }
      }
    }
  });

  test('the perfect answer to every exercise is graded correct', () {
    for (final exercise in exercises) {
      if (exercise.kind == ExerciseKind.writing) continue; // own test below
      final result = evaluator.evaluate(exercise, _perfectResponse(exercise));
      expect(result.isCorrect, isTrue,
          reason: '${exercise.id} (${exercise.kind.name})');
    }
  });

  test('every model writing answer would pass the assessor', () {
    const assessor = WritingAssessor();
    final writing = exercises.where((e) => e.kind == ExerciseKind.writing);
    expect(writing, isNotEmpty);
    for (final exercise in writing) {
      final assessment = assessor.assess(exercise.answer, exercise.brief!);
      expect(assessment.score, greaterThanOrEqualTo(WritingAssessor.passMark),
          reason: '${exercise.id}: ${assessment.notes}');
      expect(assessment.pointsCovered.every((c) => c), isTrue,
          reason: '${exercise.id} model misses a content point');
      expect(
          assessment.wordCount, greaterThanOrEqualTo(exercise.brief!.minWords),
          reason: '${exercise.id} model is shorter than its own minimum');
    }
  });

  test('a lazy answer does not pass writing tasks', () {
    const assessor = WritingAssessor();
    for (final exercise
        in exercises.where((e) => e.kind == ExerciseKind.writing)) {
      expect(assessor.assess('Hallo.', exercise.brief!).score,
          lessThan(WritingAssessor.passMark),
          reason: exercise.id);
    }
  });

  test('speaking targets match themselves and reject unrelated speech', () {
    const matcher = SpeechMatcher();
    for (final e in exercises.where((e) => e.kind == ExerciseKind.speaking)) {
      expect(matcher.bestSimilarity(e.answer, e.acceptedAnswers),
          greaterThanOrEqualTo(SpeechMatcher.passMark));
      expect(
          matcher.bestSimilarity(
              'Das Wetter ist heute schön', e.acceptedAnswers),
          lessThan(SpeechMatcher.passMark),
          reason: e.id);
    }
  });

  test('exam-style tasks cover all four Goethe skills', () {
    final byArea = <SkillArea, int>{};
    for (final e in exercises.where((e) => e.examPart != null)) {
      byArea[e.area] = (byArea[e.area] ?? 0) + 1;
    }
    for (final area in [
      SkillArea.reading,
      SkillArea.listening,
      SkillArea.writing,
      SkillArea.speaking,
    ]) {
      expect(byArea[area] ?? 0, greaterThanOrEqualTo(3), reason: area.label);
    }
  });

  test('each exam family trains all four modules at every level it covers', () {
    for (final family in ['goethe', 'testdaf']) {
      final exercises = [
        for (final l in lessons.where((l) => l.exam == family))
          ...l.exercises.where((e) => e.examPart != null),
      ];
      for (final area in [
        SkillArea.reading,
        SkillArea.listening,
        SkillArea.writing,
        SkillArea.speaking,
      ]) {
        expect(exercises.where((e) => e.area == area), isNotEmpty,
            reason: '$family has no ${area.label} tasks');
      }
    }
  });

  test('every level from A1 to B2 has a real body of lessons', () {
    for (final entry in {
      CefrLevel.a1: 10,
      CefrLevel.a2: 10,
      CefrLevel.b1: 8,
      CefrLevel.b2: 8,
    }.entries) {
      expect(lessons.where((l) => l.level == entry.key).length,
          greaterThanOrEqualTo(entry.value),
          reason: entry.key.label);
    }
  });

  test('exam lessons are tagged and aimed at the matching goal', () {
    final exam = lessons.where((l) => l.exam != null);
    expect(exam, isNotEmpty);
    for (final lesson in exam) {
      final goal =
          lesson.exam == 'goethe' ? LearningGoal.goethe : LearningGoal.testdaf;
      expect(lesson.goals, contains(goal), reason: lesson.id);
    }
  });

  test('dialogues are well formed', () {
    final dialogues = loadCourseDialogues();
    expect(dialogues.length, greaterThanOrEqualTo(6));
    for (final dialogue in dialogues) {
      expect(dialogue.gapCount, greaterThan(0), reason: dialogue.id);
      for (final turn in dialogue.turns.where((t) => t.isLearner)) {
        expect(turn.options, contains(turn.answer), reason: dialogue.id);
        expect(turn.options.toSet(), hasLength(turn.options.length));
      }
    }
  });
}
