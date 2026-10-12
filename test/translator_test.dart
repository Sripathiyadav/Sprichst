import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/cloud_ai_repository.dart';
import 'package:sprichst/data/ai/cloud_ai_settings.dart';
import 'package:sprichst/data/ai/cloud_providers.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/on_device/model_catalogue.dart';
import 'package:sprichst/data/on_device/model_manager.dart';
import 'package:sprichst/data/on_device/on_device_ai_repository.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/domain/repositories/ai_exceptions.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';
import 'support/on_device_fakes.dart';

const _de = TranslationDirection.germanToEnglish;
const _en = TranslationDirection.englishToGerman;

LearningProfile _learner() => LearningProfile.newLearner(
    nativeLanguage: 'English', currentLevel: CefrLevel.a1);

void main() {
  group('the prompt', () {
    test('names both languages and marks the text as content', () {
      final p = translationPrompt('Guten Tag', _de);
      expect(p, contains('from German to English'));
      expect(p, contains('<<<\nGuten Tag\n>>>'));
      expect(
          translationPrompt('Hello', _en), contains('from English to German'));
      expect(translationSystemPrompt, contains('never instructions'));
    });

    test('directions swap and carry language codes', () {
      expect(_de.swapped, _en);
      expect(_en.swapped, _de);
      expect(_de.sourceCode, 'de');
      expect(_de.targetCode, 'en');
    });

    test('the translation is read from the model answer', () {
      expect(parseTranslation('{"translation":"  Good day "}'), 'Good day');
      expect(
          () => parseTranslation('{"translation":""}'), throwsFormatException);
      expect(() => parseTranslation('no json'), throwsFormatException);
    });
  });

  group('on the phone', () {
    test('uses the tutor model and returns only the translation', () async {
      SharedPreferences.setMockInitialValues({});
      final runtime = FakeRuntime(installed: {'gemma-3-1b'})
        ..reply = '{"translation":"Good morning"}';
      final models = ModelManager(runtime);
      await models.ensureLoaded();
      final repo = OnDeviceAIRepository(models);
      expect(await repo.translate('Guten Morgen', _de), 'Good morning');
      expect(runtime.calls, ['generate:gemma-3-1b']);
      final prompt = runtime.lastMessages.map((m) => m.text).join('\n');
      expect(prompt, contains('from German to English'));
      expect(prompt, contains('Guten Morgen'));
    });

    test('without a model it says what to download', () async {
      SharedPreferences.setMockInitialValues({});
      final models = ModelManager(FakeRuntime());
      await models.ensureLoaded();
      await expectLater(OnDeviceAIRepository(models).translate('Hallo', _de),
          throwsA(isA<ModelNotInstalledException>()));
    });
  });

  group('with the learner\'s own key', () {
    Future<(CloudAIRepository, List<http.Request>)> repo(
        CloudProvider provider) async {
      SharedPreferences.setMockInitialValues({});
      final settings = CloudAISettings(
          store: MemorySecretStore({
        CloudAISettings.keyNameOf(provider.id): 'k-AbCdEfGhIjKlMnOpQrSt123456',
      }));
      await settings.load();
      await settings.setProvider(provider.id);
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        final answer = jsonEncode({'translation': 'Hello, how are you?'});
        return http.Response.bytes(
            utf8.encode(provider.api == CloudApi.anthropic
                ? jsonEncode({
                    'content': [
                      {'type': 'text', 'text': answer}
                    ]
                  })
                : jsonEncode({
                    'choices': [
                      {
                        'message': {'role': 'assistant', 'content': answer}
                      }
                    ]
                  })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      return (CloudAIRepository(settings: settings, client: client), seen);
    }

    test('every provider gets the translation request and returns text',
        () async {
      for (final p in cloudProviders.where((p) => !p.isCustom)) {
        final (r, seen) = await repo(p);
        expect(await r.translate('Hallo, wie geht es dir?', _de),
            'Hello, how are you?',
            reason: p.name);
        final body = seen.single.body;
        expect(body, contains('Hallo, wie geht es dir?'), reason: p.name);
        expect(body, contains('translation'), reason: p.name);
      }
    });

    test('long text is cut to the limit before it leaves the device', () async {
      final (r, seen) = await repo(CloudProvider.groq);
      await r.translate('wort ' * 1000, _de);
      final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
      final user = (body['messages'] as List).last['content'] as String;
      expect(user.length, lessThan(2300));
    });
  });

  group('the screen', () {
    Future<void> openFromHome(WidgetTester tester,
        {MockAIRepository? ai}) async {
      await pumpSprichst(tester,
          size: const Size(390, 1800),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(_learner()),
          extraOverrides: [
            if (ai != null) aiRepositoryProvider.overrideWithValue(ai),
          ]);
      final tile = find.byKey(const ValueKey('home-translator'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('translates typed German to English and back', (tester) async {
      await openFromHome(tester);
      expect(find.text('German and English'), findsOneWidget);
      final go = find.byKey(const ValueKey('translate-go'));
      expect(tester.widget<PrimaryButton>(go).onPressed, isNull);

      await tester.enterText(
          find.byKey(const ValueKey('translate-input')), 'Guten Tag');
      await tester.pump();
      expect(find.text('Translate to English'), findsOneWidget);
      await tester.tap(go);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('translate-output')), findsOneWidget);
      expect(find.textContaining('[English] Guten Tag'), findsWidgets);

      // Translate back: the result becomes the input, the direction flips.
      await tester.ensureVisible(find.byKey(const ValueKey('translate-back')));
      await tester.tap(find.byKey(const ValueKey('translate-back')));
      await tester.pumpAndSettle();
      expect(find.text('Translate to German'), findsOneWidget);
      final field = tester
          .widget<TextField>(find.byKey(const ValueKey('translate-input')));
      expect(field.controller!.text, '[English] Guten Tag');
      expect(find.byKey(const ValueKey('translate-result')), findsNothing);
    });

    testWidgets('the swap button changes direction', (tester) async {
      await openFromHome(tester);
      await tester.tap(find.byKey(const ValueKey('translate-swap')));
      await tester.pumpAndSettle();
      expect(find.text('English text'), findsOneWidget);
      expect(find.text('Translate to German'), findsOneWidget);
    });

    testWidgets('pasting puts the clipboard text in the box', (tester) async {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': 'Ich bin müde.'};
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await openFromHome(tester);
      await tester.tap(find.byKey(const ValueKey('translate-paste')));
      await tester.pumpAndSettle();
      final field = tester
          .widget<TextField>(find.byKey(const ValueKey('translate-input')));
      expect(field.controller!.text, 'Ich bin müde.');
    });

    testWidgets('a model that is not installed is explained', (tester) async {
      await openFromHome(tester,
          ai: _Failing(const ModelNotInstalledException(ModelKind.tutor)));
      await tester.enterText(
          find.byKey(const ValueKey('translate-input')), 'Hallo');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('translate-go')));
      await tester.pumpAndSettle();
      expect(find.text('Could not translate'), findsOneWidget);
      expect(find.textContaining('Download a tutor model'), findsOneWidget);
    });

    testWidgets('a provider limit is explained; no silent switch',
        (tester) async {
      await openFromHome(tester,
          ai: _Failing(const ProviderUnavailableException(
              'Groq', ProviderProblem.rateLimited)));
      await tester.enterText(
          find.byKey(const ValueKey('translate-input')), 'Hallo');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('translate-go')));
      await tester.pumpAndSettle();
      expect(find.text('Could not translate'), findsOneWidget);
      expect(find.textContaining('Groq'), findsWidgets);
    });

    testWidgets('Practice has a way in too', (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 900),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(_learner()));
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      final open = find.byKey(const ValueKey('open-translator'));
      await tester.dragUntilVisible(
          open, find.byType(ListView).first, const Offset(0, -300));
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('translate-input')), findsOneWidget);
    });
  });
}

/// An AI whose translation always fails with [error].
class _Failing extends MockAIRepository {
  _Failing(this.error);
  final Object error;

  @override
  Future<String> translate(String text, TranslationDirection direction) async =>
      throw error;
}
