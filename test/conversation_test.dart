import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/http_ai_repository.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/on_device/on_device_ai_repository.dart';
import 'package:sprichst/domain/learning/conversation_guard.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/shared/input_rules.dart';

import 'support/fakes.dart';

const _guard = ConversationGuard();

TutorReply _reply(String reply, String followUp) =>
    TutorReply(reply: reply, followUp: followUp);

List<ConversationTurn> _history(List<String> lines) => [
      for (var i = 0; i < lines.length; i++)
        i.isEven
            ? ConversationTurn.learner(lines[i])
            : ConversationTurn.tutor(lines[i]),
    ];

void main() {
  group('the guard replaces a question that was already asked', () {
    test('the learner said their name, so it is not asked again', () {
      final history = _history([
        'Hallo.',
        'Hallo! Wie heißt du?',
        'Ich bin Mord.',
      ]);
      final fresh = _guard.freshen(
          _reply('Schön, dich kennenzulernen!', 'Wie heißt du?'), history,
          level: 'A1');
      expect(fresh.followUp, isNot(contains('heißt')));
      expect(fresh.followUp, endsWith('?'));
      expect(fresh.reply, 'Schön, dich kennenzulernen!');
    });

    test('a name that was asked but not answered is not asked twice', () {
      final history = _history(['Hallo.', 'Hallo! Wie heißt du?', 'Gut.']);
      final fresh = _guard
          .freshen(_reply('Okay.', 'Wie ist dein Name?'), history, level: 'A1');
      expect(fresh.followUp, isNot(contains('Name')));
    });

    test('a paraphrase of an earlier question counts as a repeat', () {
      final history = _history([
        'Hallo.',
        'Hallo! Wie geht es dir?',
        'Gut.',
      ]);
      final fresh = _guard.freshen(
          _reply('Super.', 'Wie geht es dir denn heute?'), history,
          level: 'A1');
      expect(fresh.followUp, isNot(contains('geht es dir')));
    });

    test('a new question is kept exactly as the model wrote it', () {
      final history = _history(['Hallo.', 'Hallo! Wie heißt du?']);
      final fresh = _guard.freshen(
          _reply('Gut!', 'Was machst du am Wochenende?'), history,
          level: 'A1');
      expect(fresh.followUp, 'Was machst du am Wochenende?');
    });

    test('with no history nothing is replaced', () {
      final fresh = _guard.freshen(_reply('Hallo!', 'Wie heißt du?'), const [],
          level: 'A1');
      expect(fresh.followUp, 'Wie heißt du?');
    });

    test('a missing question is filled in', () {
      final fresh = _guard.freshen(_reply('Gut!', ''), const [], level: 'A2');
      expect(fresh.followUp, endsWith('?'));
    });
  });

  group('one question per reply', () {
    test('a question inside the reply moves to the question slot', () {
      final fresh = _guard.freshen(_reply('Schön! Wo wohnst du?', ''), const [],
          level: 'A1');
      expect(fresh.reply, 'Schön!');
      expect(fresh.followUp, 'Wo wohnst du?');
    });

    test('with two questions the fresh one is kept', () {
      final history = _history(['Hallo.', 'Hallo! Wie geht es dir?', 'Gut.']);
      final fresh = _guard.freshen(
          _reply('Super! Wie geht es dir?', 'Was machst du heute?'), history,
          level: 'A1');
      expect(fresh.reply, 'Super!');
      expect(fresh.followUp, 'Was machst du heute?');
    });

    test('correction and explanation are passed through untouched', () {
      final fresh = _guard.freshen(
          const TutorReply(
              reply: 'Fast!',
              correction: 'Ich gehe.',
              explanation: 'gehen → gehe',
              followUp: 'Wohin gehst du?'),
          const [],
          level: 'A1');
      expect(fresh.correction, 'Ich gehe.');
      expect(fresh.explanation, 'gehen → gehe');
    });
  });

  group('fallback questions', () {
    test('a model stuck on one question never repeats across a long chat', () {
      final history = <ConversationTurn>[];
      final asked = <String>[];
      for (var turn = 0; turn < 25; turn++) {
        final fresh = _guard.freshen(_reply('Okay.', 'Wie heißt du?'), history,
            level: 'B1');
        asked.add(fresh.followUp);
        history
          ..add(ConversationTurn.learner('Nachricht $turn'))
          ..add(ConversationTurn.tutor('${fresh.reply} ${fresh.followUp}'));
      }
      expect(asked.toSet().length, asked.length, reason: asked.join('\n'));
    });

    test('they suit the level', () {
      final beginner = <String>{};
      final history = <ConversationTurn>[];
      for (var turn = 0; turn < 8; turn++) {
        final fresh = _guard.freshen(_reply('', 'Wie heißt du?'), history,
            level: 'A0 / Pre-A1');
        beginner.add(fresh.followUp);
        history
          ..add(const ConversationTurn.learner('Ja.'))
          ..add(ConversationTurn.tutor(fresh.followUp));
      }
      final allowed = conversationStarters
          .where((s) => s.level == 0)
          .map((s) => s.text)
          .toSet();
      // The first reply may be the model's own ("Wie heißt du?"); the rest are
      // fallbacks and must be Pre-A1 questions.
      expect(beginner.difference(allowed), {'Wie heißt du?'});
    });

    test('every starter is a question and unique', () {
      final texts = conversationStarters.map((s) => s.text).toList();
      expect(texts.toSet().length, texts.length);
      expect(texts.every((t) => t.endsWith('?')), isTrue);
    });
  });

  group('the controller remembers the conversation', () {
    late _Echo ai;
    late AppController app;

    setUp(() async {
      ai = _Echo();
      app = AppController(
        learningRepository: InMemoryLearningRepository(
          LearningProfile.newLearner(
              nativeLanguage: 'English', currentLevel: CefrLevel.a1),
        ),
        aiRepository: ai,
      );
      await app.initialize();
    });

    test('sends earlier turns with each message', () async {
      await app.chat('Hallo.');
      await app.chat('Ich bin Mord.');
      expect(ai.seen[0], isEmpty);
      expect(ai.seen[1].map((t) => t.text).toList(),
          ['Hallo.', startsWith('Hallo!')]);
      expect(ai.seen[1].first.fromLearner, isTrue);
      expect(ai.seen[1].last.fromLearner, isFalse);
    });

    test('a model that keeps asking the same thing gets different questions',
        () async {
      final questions = <String>[];
      for (final text in ['Hallo.', 'Ich bin Mord.', 'Gut.', 'Ja.']) {
        questions.add((await app.chat(text)).followUp);
      }
      expect(questions.toSet().length, questions.length,
          reason: questions.join('\n'));
      expect(questions.skip(1).any((q) => q.contains('heißt')), isFalse);
    });

    test('keeps only the latest turns', () async {
      for (var i = 0; i < 10; i++) {
        await app.chat('Nachricht $i');
      }
      expect(app.conversation.length, ConversationGuard.maxTurns);
      expect(app.conversation.last.fromLearner, isFalse);
      expect(app.conversation[app.conversation.length - 2].text, 'Nachricht 9');
    });

    test('a new conversation starts clean', () async {
      await app.chat('Hallo.');
      app.startNewConversation();
      await app.chat('Hallo.');
      expect(ai.seen.last, isEmpty);
    });
  });

  group('what is sent', () {
    test('the server gets the turns, cleaned and limited', () async {
      late Map<String, dynamic> sent;
      final repository = HttpAIRepository(
        baseUrl: 'http://x:8000',
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"reply":"Hallo","followUp":""}', 200);
        }),
      );
      await repository.chat(
        'Hallo',
        TutorContext(level: 'A1', conversation: [
          for (var i = 0; i < 12; i++)
            i.isEven
                ? ConversationTurn.learner('l$i ${'x' * 800}')
                : ConversationTurn.tutor('t$i'),
          const ConversationTurn.tutor('   '),
        ]),
      );
      final turns = sent['conversation'] as List;
      expect(turns.length, InputLimits.turns);
      expect(turns.first['role'], isIn(['learner', 'tutor']));
      expect(
          turns.every((t) => (t['text'] as String).length <= InputLimits.turn),
          isTrue);
      expect(turns.any((t) => (t['text'] as String).trim().isEmpty), isFalse);
      // The newest turns are the ones kept.
      expect((turns.last['text'] as String), 't11');
    });

    test('the on-device prompt shows the conversation and forbids repeats', () {
      final prompt = chatPrompt('Ich bin Mord.', const [
        ConversationTurn.tutor('Hallo! Wie heißt du?'),
        ConversationTurn.learner('Hallo.'),
      ]);
      expect(prompt, contains('Tutor: Hallo! Wie heißt du?'));
      expect(prompt, contains('Learner: Hallo.'));
      expect(prompt, contains('Never ask something already asked'));
      expect(chatPrompt('Hallo.'), isNot(contains('Conversation so far')));
    });
  });
}

/// An AI that always says hello and asks for the learner's name, like the
/// stuck model in the bug report, and records what it was sent.
class _Echo extends MockAIRepository {
  final seen = <List<ConversationTurn>>[];

  @override
  Future<TutorReply> chat(String message, TutorContext context) async {
    seen.add(context.conversation);
    return const TutorReply(
        reply: 'Hallo! Wie geht es dir?', followUp: 'Wie heißt du?');
  }
}
