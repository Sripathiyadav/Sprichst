import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/data/ai/ai_server_settings.dart';
import 'package:sprichst/data/ai/http_ai_repository.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('address handling', () {
    test('accepts bare hosts, hosts with ports and full URLs', () {
      expect(AiServerSettings.normalise('192.168.2.212'),
          'http://192.168.2.212:8000');
      expect(AiServerSettings.normalise('  192.168.2.212:9000 '),
          'http://192.168.2.212:9000');
      expect(AiServerSettings.normalise('http://mac.local:8000/'),
          'http://mac.local:8000');
      expect(AiServerSettings.normalise('https://tutor.example.com'),
          'https://tutor.example.com');
    });

    test('rejects things that cannot be addresses', () {
      for (final bad in ['', '   ', 'ftp://host', 'http://', 'not a host']) {
        expect(AiServerSettings.normalise(bad), isNull, reason: '"$bad"');
      }
    });
  });

  group('AiServerSettings', () {
    test('uses the platform default until the learner sets an address',
        () async {
      final settings =
          AiServerSettings(defaultUrl: () => 'http://127.0.0.1:8000');
      await settings.load();
      expect(settings.url, 'http://127.0.0.1:8000');
      expect(settings.isCustom, isFalse);
    });

    test('remembers a custom address across launches', () async {
      final first = AiServerSettings(defaultUrl: () => 'http://127.0.0.1:8000');
      await first.load();
      expect(await first.save('192.168.2.212'), isTrue);
      expect(first.url, 'http://192.168.2.212:8000');

      final second =
          AiServerSettings(defaultUrl: () => 'http://127.0.0.1:8000');
      await second.load();
      expect(second.url, 'http://192.168.2.212:8000');
      expect(second.isCustom, isTrue);
    });

    test(
        'an invalid address changes nothing; an empty one restores the default',
        () async {
      final settings =
          AiServerSettings(defaultUrl: () => 'http://127.0.0.1:8000');
      await settings.load();
      await settings.save('192.168.2.212');
      expect(await settings.save('not a host'), isFalse);
      expect(settings.url, 'http://192.168.2.212:8000');
      expect(await settings.save(''), isTrue);
      expect(settings.url, 'http://127.0.0.1:8000');
      expect(settings.isCustom, isFalse);
    });

    test('typing the default address back in is not a custom address',
        () async {
      final settings =
          AiServerSettings(defaultUrl: () => 'http://127.0.0.1:8000');
      await settings.load();
      expect(await settings.save('127.0.0.1'), isTrue);
      expect(settings.isCustom, isFalse);
    });

    test('the repository follows the setting without being rebuilt', () async {
      final settings =
          AiServerSettings(defaultUrl: () => 'http://127.0.0.1:8000');
      await settings.load();
      final requested = <Uri>[];
      final repository = HttpAIRepository.dynamic(
        baseUrl: () => settings.url,
        client: MockClient((request) async {
          requested.add(request.url);
          return http.Response('{"default":"x","voices":[]}', 200);
        }),
      );
      await repository.listVoices();
      await settings.save('192.168.2.212');
      await repository.listVoices();
      expect(requested.map((u) => u.host), ['127.0.0.1', '192.168.2.212']);
    });
  });

  group('connection test', () {
    test('reports success', () async {
      final report = await checkAiServer('http://x:8000',
          client:
              MockClient((_) async => http.Response('{"status":"ok"}', 200)));
      expect(report.isOk, isTrue);
    });

    test('explains a refused connection to the loopback address', () async {
      final report = await checkAiServer('http://127.0.0.1:8000',
          client:
              MockClient((_) async => throw const SocketException('refused')));
      expect(report.isOk, isFalse);
      expect(report.hint, contains('127.0.0.1 means this device itself'));
    });

    test('explains a refused connection to another address', () async {
      final report = await checkAiServer('http://192.168.1.20:8000',
          client:
              MockClient((_) async => throw http.ClientException('refused')));
      expect(report.hint, contains('run.sh'));
    });

    test('a silent network is reported as a timeout with Wi-Fi advice',
        () async {
      final report = await checkAiServer('http://192.168.1.20:8000',
          timeout: const Duration(milliseconds: 20),
          client: MockClient((_) => Completer<http.Response>().future));
      expect(report.isOk, isFalse);
      expect(report.hint, contains('same Wi-Fi'));
    });

    test('something else on that port is not mistaken for the server',
        () async {
      final report = await checkAiServer('http://192.168.1.20:8000',
          client: MockClient((_) async => http.Response('nope', 404)));
      expect(report.isOk, isFalse);
      expect(report.detail, contains('404'));
    });
  });

  testWidgets('the AI server setting can be changed and tested in the app',
      (tester) async {
    final repository = InMemoryLearningRepository(LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.a1));
    await pumpSprichst(tester,
        size: const Size(900, 1000),
        brightness: Brightness.light,
        repository: repository);
    await tester.tap(find.text('Account').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI & voice').first);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('ai-server-address'));
    await tester.scrollUntilVisible(
      field,
      200,
      scrollable: find
          .descendant(
              of: find.byType(SettingsPage), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Developer AI server (advanced)'), findsOneWidget);
    expect(find.textContaining('Using the default address'), findsOneWidget);

    await tester.enterText(
        find.descendant(of: field, matching: find.byType(EditableText)),
        'not a host');
    await tester.ensureVisible(find.text('Save and test'));
    await tester.tap(find.text('Save and test'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('does not look like an address'), findsOneWidget);
  });
}
