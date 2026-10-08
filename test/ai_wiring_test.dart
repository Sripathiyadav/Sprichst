import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/ai_server_settings.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

/// These tests use the app's real provider wiring (only storage and the server
/// address are replaced). Every other AI test overrides the AI repository,
/// which once hid a circular dependency that made every coach request fail.
void main() {
  late HttpServer server;
  final requests = <String>[];

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      final body = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/v1/chat') {
        final message = (jsonDecode(body) as Map)['message'];
        request.response.write(jsonEncode({
          'reply': 'Hallo! Du sagtest: $message',
          'followUp': 'Wie heißt du?',
        }));
      } else if (request.uri.path == '/v1/voices') {
        request.response.write(jsonEncode({
          'default': 'de_DE-thorsten-medium',
          'voices': [
            {
              'id': 'de_DE-thorsten-medium',
              'label': 'Thorsten',
              'engine': 'piper',
              'description': 'x',
              'available': true,
            }
          ],
        }));
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  ProviderContainer container(LearningProfile profile) {
    final c = ProviderContainer(overrides: [
      learningRepositoryProvider
          .overrideWithValue(InMemoryLearningRepository(profile)),
      aiServerSettingsProvider.overrideWith((ref) => AiServerSettings(
          defaultUrl: () => 'http://127.0.0.1:${server.port}')),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  LearningProfile learner([AIProviderPreference? preference]) =>
      LearningProfile.newLearner(
              nativeLanguage: 'English', currentLevel: CefrLevel.a1)
          .copyWith(
              aiProviderPreference:
                  preference ?? AIProviderPreference.automatic);

  test('the coach reaches the AI server through the real providers', () async {
    final c = container(learner());
    final app = c.read(appControllerProvider);
    await app.initialize();

    final reply = await app.chat('Ich lerne Deutsch');
    expect(reply.reply, 'Hallo! Du sagtest: Ich lerne Deutsch');
    expect(requests, ['POST /v1/chat']);
  });

  test('the learner preference is read from the profile', () async {
    final c = container(learner(AIProviderPreference.local));
    final app = c.read(appControllerProvider);
    await app.initialize();

    // "This phone only": nothing may be sent to the server.
    await expectLater(app.chat('Hallo'), throwsA(anything));
    expect(requests, isEmpty);
  });
}
