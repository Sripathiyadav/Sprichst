import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprichst/data/ai/http_ai_repository.dart';
import 'package:sprichst/domain/learning/tutor_context_builder.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/shared/input_rules.dart';

import 'support/fakes.dart';

// Invisible characters are built from code points so none appears in this file.
String chars(List<int> codes) => String.fromCharCodes(codes);

void main() {
  group('sanitizeText', () {
    test('removes control and invisible characters but keeps German text', () {
      final dirty = 'Hal${chars([0])}lo${chars([7])} ${chars([0x202E])}'
          'Wel${chars([0x200B])}t ${chars([0xFEFF])}äöüß';
      expect(sanitizeText(dirty), 'Hallo Welt äöüß');
    });

    test('keeps tabs and line breaks, collapses long runs of blank lines', () {
      expect(sanitizeText('a\n\n\n\n\n\nb\tc'), 'a\n\n\nb\tc');
    });

    test('trims and limits length', () {
      expect(sanitizeText('  hi  '), 'hi');
      expect(sanitizeText('abcdef', maxLength: 3), 'abc');
    });

    test('never cuts an emoji in half', () {
      final grin = String.fromCharCodes([0x1F600]); // two UTF-16 units
      final cut = sanitizeText('ab$grin', maxLength: 3);
      expect(cut, 'ab');
      expect(sanitizeText('a$grin', maxLength: 3), 'a$grin');
    });

    test('names are one line, with single spaces, and at most 40 characters',
        () {
      expect(sanitizeName('  Sam \n  Kumar  '), 'Sam Kumar');
      expect(sanitizeName('x' * 100).length, InputLimits.name);
      expect(sanitizeName('   '), '');
    });

    test('lists drop empty items and respect both limits', () {
      final result = sanitizeList(
        ['  a  ', '', 'b' * 10, 'c', 'd'],
        max: 3,
        maxLength: 4,
      );
      expect(result, ['a', 'bbbb', 'c']);
    });
  });

  group('what the app sends to the AI server', () {
    test('every learner context stays inside the server limits', () {
      final course = Curriculum(loadCourse());
      const builder = TutorContextBuilder();
      var profile = LearningProfile.newLearner(
          nativeLanguage: 'English', currentLevel: CefrLevel.b2);
      // A learner who has completed every lesson: the largest context.
      profile = profile.copyWith(lessonProgress: {
        for (final lesson in course.lessons)
          lesson.id: const LessonProgress(
              status: LessonStatus.completed,
              attempts: 1,
              bestCorrect: 1,
              total: 1),
      }, recentMistakes: [
        for (var i = 0; i < 10; i++) 'Definite articles: ${'x' * 200}'
      ]);

      for (final level in CefrLevel.values) {
        for (final lesson in course.lessons) {
          final context = builder.build(
              profile.copyWith(currentLevel: level), course,
              currentLesson: lesson);
          expect(RegExp(r'^[A-Za-z0-9 /().+\-]{1,30}$').hasMatch(context.level),
              isTrue,
              reason: context.level);
          expect((lesson.unit).length, lessThanOrEqualTo(InputLimits.medium));
          expect(lesson.title.length, lessThanOrEqualTo(InputLimits.medium));
        }
      }
    });

    test('the request body is cleaned and clipped to the server limits',
        () async {
      late Map<String, dynamic> sent;
      late Map<String, String> headers;
      final repository = HttpAIRepository(
        baseUrl: 'http://x:8000',
        authToken: () async => 'abc.def.ghi',
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          headers = request.headers;
          return http.Response('{"reply":"Hallo","followUp":""}', 200);
        }),
      );
      await repository.chat(
        'Hallo',
        TutorContext(
          level: 'A1',
          unit: 'u' * 500,
          lesson: 'Lektion${chars([0x202E])}',
          weakSkills: List.filled(20, 's' * 100),
          knownVocabulary: List.filled(80, 'w' * 100),
          recentMistakes: List.filled(40, 'm' * 400),
        ),
      );
      final context = sent['context'] as Map<String, dynamic>;
      expect((context['current_unit'] as String).length, InputLimits.medium);
      expect(context['current_lesson'], 'Lektion');
      expect((context['weak_skills'] as List).length, InputLimits.weakSkills);
      expect((context['weak_skills'] as List).first.length, InputLimits.short);
      expect(
          (context['known_vocabulary'] as List).length, InputLimits.vocabulary);
      expect((context['recent_mistakes'] as List).length, InputLimits.mistakes);
      expect((context['recent_mistakes'] as List).first.length,
          InputLimits.medium);
      expect(headers['Authorization'], 'Bearer abc.def.ghi');
    });

    test('no sign-in header is sent when signed out', () async {
      late Map<String, String> headers;
      final repository = HttpAIRepository(
        baseUrl: 'http://x:8000',
        authToken: () async => null,
        client: MockClient((request) async {
          headers = request.headers;
          return http.Response('{"default":"x","voices":[]}', 200);
        }),
      );
      await repository.listVoices();
      expect(headers.containsKey('Authorization'), isFalse);
    });
  });
}
