import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/data/curriculum_parser.dart';
import 'package:sprichst/data/local/local_learning_repository.dart';

import 'support/fakes.dart';

Map<String, dynamic> _exercise([Map<String, dynamic> overrides = const {}]) => {
      'id': 'e1',
      'kind': 'multipleChoice',
      'area': 'grammar',
      'prompt': 'Pick',
      'options': ['der', 'die'],
      'answer': 'der',
      'explanation': 'Because.',
      'skills': ['definite_articles'],
      ...overrides,
    };

String _course(List<Map<String, dynamic>> exercises,
        {String lessonId = 'l1'}) =>
    jsonEncode({
      'lessons': [
        {
          'id': lessonId,
          'level': 'a1',
          'unit': 'U',
          'title': 'T',
          'durationMinutes': 5,
          'objective': 'O',
          'introduction': 'I',
          'examples': ['x'],
          'exercises': exercises,
        },
      ],
    });

void main() {
  testWidgets('the repository loads the course through the asset bundle',
      (tester) async {
    final lessons = await LocalLearningRepository().loadLessons();
    expect(lessons, hasLength(9));
  });

  test('parses the bundled course', () {
    final lessons = loadCourse();
    expect(lessons, hasLength(9));
    expect(lessons.first.exercises.first.skills, isNotEmpty);
  });

  test('parses a minimal valid lesson', () {
    final lessons = CurriculumParser.parse(_course([_exercise()]));
    expect(lessons.single.exercises.single.answer, 'der');
  });

  for (final entry in <String, String>{
    'a multiple-choice answer outside its options': _course([
      _exercise({'answer': 'das'})
    ]),
    'an exercise without skills': _course([
      _exercise({'skills': <String>[]})
    ]),
    'an unknown exercise kind': _course([
      _exercise({'kind': 'karaoke'})
    ]),
    'a word-order answer that needs words not in the bank': _course([
      _exercise({
        'kind': 'wordOrder',
        'options': ['Ich', 'lerne'],
        'answer': 'Ich lerne Deutsch',
      })
    ]),
    'a lesson with no exercises': _course([]),
    'duplicate exercise ids': _course([_exercise(), _exercise()]),
    'a missing lessons list': '{}',
  }.entries) {
    test('rejects ${entry.key}', () {
      expect(() => CurriculumParser.parse(entry.value),
          throwsA(isA<FormatException>()));
    });
  }
}
