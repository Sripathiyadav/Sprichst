import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/data/ai/cloud_ai_repository.dart';
import 'package:sprichst/data/ai/cloud_ai_settings.dart';
import 'package:sprichst/data/ai/cloud_providers.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/account/cloud_provider_section.dart';

import 'support/fakes.dart';

const _key = 'gsk_' 'AbCdEfGhIjKlMnOpQrSt123456';

void main() {
  group('the built-in suggestions', () {
    test('Groq suggests models it still offers, not the retired Llamas', () {
      final ids = CloudProvider.groq.models.map((m) => m.id).toList();
      expect(ids,
          ['qwen/qwen3.8-27b', 'openai/gpt-oss-120b', 'openai/gpt-oss-20b']);
      expect(ids, isNot(contains('llama-3.3-70b-versatile')));
      expect(CloudProvider.groq.defaultModel, 'qwen/qwen3.8-27b');
      expect(CloudProvider.openRouter.defaultModel, 'openrouter/free');
    });

    test('a retired model saved by an earlier version is ignored', () async {
      SharedPreferences.setMockInitialValues({
        CloudAISettings.modelNameOf('groq'): 'llama-3.3-70b-versatile',
        CloudAISettings.modelNameOf('openrouter'):
            'meta-llama/llama-3.3-70b-instruct:free',
      });
      final settings = CloudAISettings(
          store: MemorySecretStore({CloudAISettings.keyNameOf('groq'): _key}));
      await settings.load();
      expect(settings.model, 'qwen/qwen3.8-27b');
      await settings.setProvider('openrouter');
      expect(settings.model, 'openrouter/free');
    });

    test('a model the learner chose that is not retired is kept', () async {
      SharedPreferences.setMockInitialValues(
          {CloudAISettings.modelNameOf('groq'): 'openai/gpt-oss-20b'});
      final settings = CloudAISettings(store: MemorySecretStore());
      await settings.load();
      expect(settings.model, 'openai/gpt-oss-20b');
    });

    test('replies have room for models that think first', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = CloudAISettings(
          store: MemorySecretStore({CloudAISettings.keyNameOf('groq'): _key}));
      await settings.load();
      late Map<String, dynamic> sent;
      final repo = CloudAIRepository(
          settings: settings,
          client: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
                '{"choices":[{"message":{"content":"{\\"reply\\":\\"Hi\\",\\"followUp\\":\\"?\\"}"}}]}',
                200);
          }));
      await repo.chat('Hallo', const TutorContext(level: 'A1'));
      expect(sent['max_tokens'], greaterThanOrEqualTo(1000));
    });
  });

  group('the provider\'s own model list', () {
    Future<List<String>> list(String body, CloudProvider provider) async {
      SharedPreferences.setMockInitialValues({});
      final settings = CloudAISettings(store: MemorySecretStore());
      await settings.load();
      final repo = CloudAIRepository(
          settings: settings,
          client: MockClient((request) async {
            expect(request.url.path, endsWith('/models'));
            return http.Response(body, 200);
          }));
      return repo.listModels(provider, _key);
    }

    test('chat models only, sorted, without speech, embedding or safety ones',
        () async {
      final ids = await list(
          jsonEncode({
            'data': [
              {'id': 'whisper-large-v3'},
              {'id': 'openai/gpt-oss-120b'},
              {'id': 'meta-llama/llama-prompt-guard-2-86m'},
              {'id': 'qwen/qwen3.8-27b'},
              {'id': 'text-embedding-3-small'},
              {'id': 'openai/gpt-oss-safeguard-20b'},
              {'id': 'bad id with spaces'},
              {'id': 'qwen/qwen3.8-27b'},
            ]
          }),
          CloudProvider.groq);
      expect(ids, ['openai/gpt-oss-120b', 'qwen/qwen3.8-27b']);
    });

    test('Gemini ids lose their models/ prefix', () async {
      final ids = await list(
          jsonEncode({
            'data': [
              {'id': 'models/gemini-2.5-flash'},
              {'id': 'models/text-embedding-004'},
            ]
          }),
          CloudProvider.gemini);
      expect(ids, ['gemini-2.5-flash']);
    });

    test('a bad key or an odd answer is an error or empty, never a crash',
        () async {
      expect(await list('{}', CloudProvider.groq), isEmpty);
      SharedPreferences.setMockInitialValues({});
      final settings = CloudAISettings(store: MemorySecretStore());
      await settings.load();
      final repo = CloudAIRepository(
          settings: settings,
          client: MockClient((_) async => http.Response('', 401)));
      await expectLater(
          repo.listModels(CloudProvider.groq, _key), throwsA(anything));
    });
  });

  group('the model picker', () {
    late MemorySecretStore store;
    Future<void> pump(
        WidgetTester tester, Future<List<String>> Function() lister) async {
      SharedPreferences.setMockInitialValues({});
      store = MemorySecretStore({CloudAISettings.keyNameOf('groq'): _key});
      tester.view.physicalSize = const Size(700, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          cloudAISettingsProvider
              .overrideWith((ref) => CloudAISettings(store: store)..load()),
          cloudModelListerProvider.overrideWithValue((p, k, u) => lister()),
        ],
        child: MaterialApp(
          theme: SprichstTheme.light,
          home: const Scaffold(
              body: SingleChildScrollView(child: CloudProviderSection())),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('lists what the provider offers and uses the pick',
        (tester) async {
      await pump(tester, () async => ['openai/gpt-oss-120b', 'some-new-model']);
      await tester.tap(find.byKey(const ValueKey('cloud-models')));
      await tester.pumpAndSettle();
      expect(find.text('Models from Groq'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('model-some-new-model')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
          tester.element(find.byType(CloudProviderSection)));
      expect(container.read(cloudAISettingsProvider).model, 'some-new-model');
      expect(find.text('Using some-new-model.'), findsOneWidget);
    });

    testWidgets('a failure says so in words', (tester) async {
      await pump(tester, () async => throw Exception('401'));
      await tester.tap(find.byKey(const ValueKey('cloud-models')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load the models'), findsOneWidget);
    });
  });
}
