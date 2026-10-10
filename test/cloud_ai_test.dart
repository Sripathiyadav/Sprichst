import 'dart:async';
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
import 'package:sprichst/data/ai/hybrid_ai_repository.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/on_device/model_manager.dart';
import 'package:sprichst/data/on_device/on_device_ai_repository.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/domain/repositories/ai_exceptions.dart';
import 'package:sprichst/features/account/cloud_provider_section.dart';

import 'support/fakes.dart';
import 'support/on_device_fakes.dart';

// Written in two pieces so this file itself does not look like a leaked key.
const _key = 'gsk_' 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789';
const _context = TutorContext(level: 'A1');

Future<CloudAISettings> _settings(
    {String? key, MemorySecretStore? store}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = CloudAISettings(
      store: store ??
          MemorySecretStore(
              key == null ? null : {'sprichst_groq_api_key': key}));
  await settings.load();
  return settings;
}

/// A 200 with a UTF-8 body (the umlauts and arrows in German answers need it).
http.Response _ok(String body) => http.Response.bytes(utf8.encode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

String _completion(Map<String, dynamic> content) => jsonEncode({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': jsonEncode(content)}
        }
      ]
    });

void main() {
  group('the key', () {
    test('only a key-shaped value is accepted, trimmed', () {
      expect(CloudAISettings.validKey('  $_key \n'), _key);
      for (final bad in [
        '',
        'sk-123',
        'gsk_',
        'gsk_short',
        'gsk_ spaced key',
        'gsk_${'a' * 300}'
      ]) {
        expect(CloudAISettings.validKey(bad), isNull, reason: bad);
      }
    });

    test('is saved, masked, reloaded and removed', () async {
      final store = MemorySecretStore();
      final settings = await _settings(store: store);
      expect(settings.hasKey, isFalse);
      expect(await settings.saveKey('nope'), isFalse);
      expect(await settings.saveKey(_key), isTrue);
      expect(settings.hasKey, isTrue);
      expect(settings.maskedKey, isNot(contains('AbCdEfGh')));
      expect(settings.maskedKey, endsWith(_key.substring(_key.length - 4)));

      final again = await _settings(store: store);
      expect(again.key, _key);

      await again.removeKey();
      expect(again.hasKey, isFalse);
      expect(store.values, isEmpty);
    });

    test('a store that cannot write means the key is not saved', () async {
      final store = MemorySecretStore()..failWrites = true;
      final settings = await _settings(store: store);
      expect(await settings.saveKey(_key), isFalse);
      expect(settings.hasKey, isFalse);
    });

    test('a damaged stored value is ignored', () async {
      final settings = await _settings(key: 'not a key');
      expect(settings.hasKey, isFalse);
    });

    test('the model choice is remembered; any well-formed id is allowed',
        () async {
      final settings = await _settings();
      expect(await settings.setModel('llama-3.1-8b-instant'), isTrue);
      expect(settings.model, 'llama-3.1-8b-instant');
      expect(await settings.setModel('some-other-model'), isTrue);
      expect(settings.model, 'some-other-model');
      expect(await settings.setModel('bad model; drop'), isFalse);
      expect(settings.model, 'some-other-model');
    });

    test('the key never goes into the profile that is synced', () {
      // The profile codec has no field for it; pin that nothing like it leaks.
      final profile = LearningProfile.newLearner(
          nativeLanguage: 'English', currentLevel: CefrLevel.a1);
      expect(profile.aiProviderPreference, isA<AIProviderPreference>());
      expect(jsonEncode(profile.aiModel), isNot(contains('gsk_')));
    });
  });

  group('talking to Groq', () {
    Future<(CloudAIRepository, List<http.BaseRequest>)> repo(
      Future<http.Response> Function(http.Request) reply, {
      String? key = _key,
    }) async {
      final seen = <http.BaseRequest>[];
      final client = MockClient((request) async {
        seen.add(request);
        return reply(request);
      });
      return (
        CloudAIRepository(settings: await _settings(key: key), client: client),
        seen
      );
    }

    test('a chat reply is parsed, sent with the key, the model and the history',
        () async {
      final (groq, seen) = await repo((request) async => _ok(_completion({
            'corrected': 'Ich gehe morgen.',
            'explanation': 'gehen → gehe',
            'reply': 'Fast richtig!',
            'followUp': 'Wohin gehst du?',
          })));
      final reply = await groq.chat(
        'Ich gehen morgen.',
        const TutorContext(level: 'A1', conversation: [
          ConversationTurn.tutor('Hallo! Wie heißt du?'),
          ConversationTurn.learner('Mord.'),
        ]),
      );
      expect(reply.reply, 'Fast richtig!');
      expect(reply.correction, 'Ich gehe morgen.');
      expect(reply.followUp, 'Wohin gehst du?');

      final request = seen.single as http.Request;
      expect(request.url.toString(),
          'https://api.groq.com/openai/v1/chat/completions');
      expect(request.headers['Authorization'], 'Bearer $_key');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'llama-3.3-70b-versatile');
      expect(body['response_format'], {'type': 'json_object'});
      final prompt = jsonEncode(body['messages']);
      expect(prompt, contains('Tutor: Hallo! Wie heißt du?'));
      expect(prompt, isNot(contains(_key))); // the key is a header, not text
    });

    test('a correction is parsed', () async {
      final (groq, _) = await repo((_) async => _ok(_completion({
            'correct': false,
            'corrected': 'Ich habe einen Hund.',
            'explanation': 'ein → einen',
            'followUp': 'Wie heißt er?',
          })));
      final reply = await groq.correctGerman('Ich habe ein Hund.', _context);
      expect(reply.corrected, 'Ich habe einen Hund.');
      expect(reply.wasCorrect, isFalse);
    });

    test('speech is sent to Whisper in German and read back', () async {
      final (groq, seen) =
          await repo((_) async => http.Response('{"text":" Guten Tag "}', 200));
      final result = await groq.transcribeAudio(
          const AudioCapture(
              bytes: [1, 2, 3], filename: 'a.wav', mimeType: 'audio/wav'),
          _context);
      expect(result.text, 'Guten Tag');
      expect(seen.single.url.path, endsWith('/audio/transcriptions'));
      expect(seen.single.headers['Authorization'], 'Bearer $_key');
    });

    test('there is no German voice on Groq', () async {
      final (groq, _) = await repo((_) async => http.Response('{}', 200));
      expect(() => groq.synthesizeSpeech('Hallo', _context),
          throwsUnsupportedError);
    });

    test('no key means a clear, actionable error and no request', () async {
      final (groq, seen) =
          await repo((_) async => http.Response('{}', 200), key: null);
      await expectLater(
          groq.chat('Hallo', _context),
          throwsA(isA<ProviderUnavailableException>()
              .having((e) => e.problem, 'problem', ProviderProblem.noKey)));
      expect(seen, isEmpty);
    });

    test('each failure becomes the right problem', () async {
      Future<ProviderProblem> problemFor(
          Future<http.Response> Function(http.Request) reply) async {
        final (groq, _) = await repo(reply);
        try {
          await groq.chat('Hallo', _context);
        } on ProviderUnavailableException catch (e) {
          return e.problem;
        }
        fail('expected a problem');
      }

      expect(await problemFor((_) async => http.Response('', 401)),
          ProviderProblem.invalidKey);
      expect(await problemFor((_) async => http.Response('', 403)),
          ProviderProblem.invalidKey);
      expect(await problemFor((_) async => http.Response('', 429)),
          ProviderProblem.rateLimited);
      expect(await problemFor((_) async => http.Response('', 500)),
          ProviderProblem.unavailable);
      expect(await problemFor((_) async => http.Response('', 503)),
          ProviderProblem.unavailable);
      expect(await problemFor((_) async => http.Response('not json', 200)),
          ProviderProblem.unavailable);
      expect(
          await problemFor((_) async => http.Response('{"choices":[]}', 200)),
          ProviderProblem.unavailable);
      expect(await problemFor((_) async => throw http.ClientException('x')),
          ProviderProblem.offline);
      expect(await problemFor((_) async => throw TimeoutException('slow')),
          ProviderProblem.offline);
    });

    test('how long to wait comes from the header or the message', () {
      expect(CloudAIRepository.retryAfterOf({'retry-after': '90'}, ''),
          const Duration(seconds: 90));
      expect(
          CloudAIRepository.retryAfterOf({},
              '{"error":{"message":"Rate limit reached. Please try again in 7m26.4s."}}'),
          const Duration(minutes: 7, seconds: 26, milliseconds: 400));
      expect(CloudAIRepository.retryAfterOf({}, 'Please try again in 1h2m3s'),
          const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(CloudAIRepository.retryAfterOf({}, 'try again in 850ms'), isNull);
      expect(CloudAIRepository.retryAfterOf({}, 'nothing here'), isNull);
    });

    test('errors never contain the key or the learner\'s words', () async {
      final (groq, _) = await repo((_) async =>
          http.Response('{"error":"bad $_key mein geheimer Satz"}', 401));
      try {
        await groq.chat('mein geheimer Satz', _context);
        fail('should throw');
      } on ProviderUnavailableException catch (e) {
        final text = e.toString();
        expect(text, isNot(contains(_key)));
        expect(text, isNot(contains('geheimer')));
      }
    });

    test(
        'a key is checked with the models list; "limit reached" still proves it',
        () async {
      var status = 200;
      final (groq, seen) = await repo((_) async => http.Response('{}', status));
      expect(await groq.verifyKey(CloudProvider.groq, _key), isNull);
      expect(seen.single.url.path, endsWith('/models'));
      status = 401;
      expect(await groq.verifyKey(CloudProvider.groq, _key),
          ProviderProblem.invalidKey);
      status = 429;
      expect(await groq.verifyKey(CloudProvider.groq, _key), isNull);
      status = 500;
      expect(await groq.verifyKey(CloudProvider.groq, _key),
          ProviderProblem.unavailable);
    });

    test('messages tell the learner what to do', () {
      const limited = ProviderUnavailableException(
          'Groq', ProviderProblem.rateLimited,
          retryAfter: Duration(minutes: 7, seconds: 26));
      expect(limited.toString(), contains('7 min'));
      expect(limited.toString(), contains('this phone'));
      expect(limited.canOfferPhone, isTrue);
      const noKey = ProviderUnavailableException('Groq', ProviderProblem.noKey);
      expect(noKey.canOfferPhone, isFalse);
      expect(noKey.toString(), contains('Account → AI & voice'));
    });
  });

  group('any provider', () {
    const fakeKey = 'k-AbCdEfGhIjKlMnOpQrSt123456';

    Future<(CloudAIRepository, List<http.Request>)> forProvider(
      CloudProvider provider,
      Future<http.Response> Function(http.Request) reply, {
      String? baseUrl,
      String? model,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final settings = CloudAISettings(
          store: MemorySecretStore({
        CloudAISettings.keyNameOf(provider.id): fakeKey,
      }));
      await settings.load();
      await settings.setProvider(provider.id);
      if (baseUrl != null) await settings.setCustomBaseUrl(baseUrl);
      if (model != null) await settings.setModel(model);
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        return reply(request);
      });
      return (CloudAIRepository(settings: settings, client: client), seen);
    }

    final answer = {
      'corrected': 'Ich gehe.',
      'explanation': 'gehen → gehe',
      'reply': 'Gut!',
      'followUp': 'Wohin?',
    };

    test('every provider is spoken to at its own address, with its own header',
        () async {
      for (final p in cloudProviders.where((p) => !p.isCustom)) {
        final (repo, seen) = await forProvider(p, (_) async {
          return p.api == CloudApi.anthropic
              ? _ok(jsonEncode({
                  'content': [
                    {'type': 'text', 'text': jsonEncode(answer)}
                  ]
                }))
              : _ok(_completion(answer));
        });
        expect((await repo.chat('Ich gehen.', _context)).reply, 'Gut!',
            reason: p.name);
        final request = seen.single;
        final path =
            p.api == CloudApi.anthropic ? '/messages' : '/chat/completions';
        expect(request.url.toString(), '${p.baseUrl}$path', reason: p.name);
        expect(request.url.scheme, 'https', reason: p.name);
        if (p.api == CloudApi.anthropic) {
          expect(request.headers['x-api-key'], fakeKey);
          expect(request.headers['anthropic-version'], '2023-06-01');
          expect(request.headers.containsKey('Authorization'), isFalse);
        } else {
          expect(request.headers['Authorization'], 'Bearer $fakeKey');
        }
        // The key is only ever a header.
        expect(request.body, isNot(contains(fakeKey)), reason: p.name);
      }
    });

    test('Anthropic gets the Messages shape, OpenAI the newer token field',
        () async {
      final (claude, seenClaude) = await forProvider(
          CloudProvider.anthropic,
          (_) async => _ok(jsonEncode({
                'content': [
                  {'type': 'text', 'text': jsonEncode(answer)}
                ]
              })));
      await claude.chat('Hallo', _context);
      final c = jsonDecode(seenClaude.single.body) as Map<String, dynamic>;
      expect(c['system'], isA<String>());
      expect((c['messages'] as List).single['role'], 'user');
      expect(c['max_tokens'], isA<int>());
      expect(c.containsKey('response_format'), isFalse);

      final (gpt, seenGpt) = await forProvider(
          CloudProvider.openAi, (_) async => _ok(_completion(answer)));
      await gpt.chat('Hallo', _context);
      final g = jsonDecode(seenGpt.single.body) as Map<String, dynamic>;
      expect(g['max_completion_tokens'], isA<int>());
      expect(g.containsKey('max_tokens'), isFalse);
      expect(g['response_format'], {'type': 'json_object'});
    });

    test('Gemini and OpenRouter are not sent a response_format', () async {
      for (final p in [CloudProvider.gemini, CloudProvider.openRouter]) {
        final (repo, seen) =
            await forProvider(p, (_) async => _ok(_completion(answer)));
        await repo.chat('Hallo', _context);
        final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
        expect(body.containsKey('response_format'), isFalse, reason: p.name);
      }
    });

    test('a model typed by the learner is the one sent', () async {
      final (repo, seen) = await forProvider(
          CloudProvider.openRouter, (_) async => _ok(_completion(answer)),
          model: 'meta-llama/llama-3.3-70b-instruct:free');
      await repo.chat('Hallo', _context);
      expect(jsonDecode(seen.single.body)['model'],
          'meta-llama/llama-3.3-70b-instruct:free');
    });

    test('a custom server uses the typed address, and works without a key',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = CloudAISettings(store: MemorySecretStore());
      await settings.load();
      await settings.setProvider('custom');
      expect(settings.isConfigured, isFalse); // no address, no model yet
      expect(await settings.setCustomBaseUrl('http://example.com/v1'), isFalse);
      expect(
          await settings
              .setCustomBaseUrl('https://example.com/v1/chat/completions/'),
          isTrue);
      expect(settings.baseUrl, 'https://example.com/v1');
      await settings.setModel('my-model');
      expect(settings.isConfigured, isTrue);

      final seen = <http.Request>[];
      final repo = CloudAIRepository(
          settings: settings,
          client: MockClient((request) async {
            seen.add(request);
            return _ok(_completion(answer));
          }));
      await repo.chat('Hallo', _context);
      expect(seen.single.url.toString(),
          'https://example.com/v1/chat/completions');
      expect(seen.single.headers.containsKey('Authorization'), isFalse);
    });

    test('addresses must be https and clean', () {
      for (final bad in [
        '',
        'http://example.com/v1',
        'ftp://example.com',
        'https://user:pw@example.com/v1',
        'https://example.com/v1?key=1',
        'https://example.com/v1#x',
        'not a url',
      ]) {
        expect(CloudAISettings.validBaseUrl(bad), isNull, reason: bad);
      }
      expect(CloudAISettings.validBaseUrl(' https://example.com/v1/ '),
          'https://example.com/v1');
    });

    test('each provider keeps its own key and model', () async {
      final store = MemorySecretStore();
      SharedPreferences.setMockInitialValues({});
      final settings = CloudAISettings(store: store);
      await settings.load();
      await settings.saveKey(_key); // Groq, the default
      await settings.setProvider('openai');
      expect(settings.hasKey, isFalse);
      await settings.saveKey(_key.replaceFirst('gsk_', 'sk_o'));
      await settings.setModel('gpt-4.1');
      await settings.setProvider('groq');
      expect(settings.key, _key);
      expect(settings.model, 'llama-3.3-70b-versatile');
      await settings.setProvider('openai');
      expect(settings.model, 'gpt-4.1');
      expect(
          store.values.keys,
          containsAll([
            'sprichst_groq_api_key',
            'sprichst_openai_api_key',
          ]));
      await settings.setProvider('nonsense');
      expect(settings.provider.id, 'openai');
    });

    test('a key saved by an earlier version (Groq) still loads', () async {
      final settings = await _settings(key: _key);
      expect(settings.provider.id, 'groq');
      expect(settings.key, _key);
      expect(settings.isConfigured, isTrue);
    });

    test('provider-specific errors become the right problem', () {
      ProviderProblem p(int code, String body) =>
          CloudAIRepository.problemOf(code, body);
      expect(
          p(400,
              '{"error":{"message":"API key not valid. Please pass a valid API key."}}'),
          ProviderProblem.invalidKey); // Gemini
      expect(p(401, '{"error":{"message":"invalid x-api-key"}}'),
          ProviderProblem.invalidKey); // Anthropic
      expect(p(429, '{"error":{"code":"insufficient_quota"}}'),
          ProviderProblem.noCredit); // OpenAI
      expect(p(400, '{"error":{"message":"Your credit balance is too low"}}'),
          ProviderProblem.noCredit); // Anthropic
      expect(p(402, ''), ProviderProblem.noCredit);
      expect(p(429, ''), ProviderProblem.rateLimited);
      expect(p(404, '{"error":{"message":"model not found"}}'),
          ProviderProblem.unknownModel);
      expect(p(400, '{"error":{"message":"The model `x` does not exist"}}'),
          ProviderProblem.unknownModel);
      expect(p(500, ''), ProviderProblem.unavailable);
      expect(p(529, 'overloaded'), ProviderProblem.unavailable);
    });

    test('the learner is told what to do for the new problems', () {
      const credit =
          ProviderUnavailableException('OpenAI', ProviderProblem.noCredit);
      const model =
          ProviderUnavailableException('OpenAI', ProviderProblem.unknownModel);
      expect(credit.toString(), contains('OpenAI'));
      expect(credit.canOfferPhone, isTrue);
      expect(model.canOfferPhone, isFalse);
    });

    test('providers without speech recognition fall back to the phone',
        () async {
      for (final p in cloudProviders) {
        expect(p.canTranscribe, p.id == 'groq' || p.id == 'openai',
            reason: p.name);
      }
      SharedPreferences.setMockInitialValues({});
      final runtime = FakeRuntime(installed: {'whisper-base'})..reply = '';
      final models = ModelManager(runtime);
      await models.ensureLoaded();
      final cloud = _Cloud();
      final repo = HybridAIRepository(
        onDevice: OnDeviceAIRepository(models),
        server: _ServerAI(),
        cloud: cloud,
        cloudAvailable: () => true,
        cloudCanTranscribe: () => false,
        serverEnabled: () => false,
        models: models,
        preference: () => AIProviderPreference.cloud,
      );
      const audio =
          AudioCapture(bytes: [1], filename: 'a.wav', mimeType: 'audio/wav');
      try {
        await repo.transcribeAudio(audio, _context);
      } catch (_) {}
      expect(cloud.calls, 0, reason: 'the recording must stay on the phone');
    });

    test('the saved preference keeps its old name so nothing breaks', () {
      expect(AIProviderPreference.cloud.storedName, 'groq');
      expect(AIProviderPreference.fromName('groq'), AIProviderPreference.cloud);
      expect(
          AIProviderPreference.fromName('cloud'), AIProviderPreference.cloud);
      expect(
          AIProviderPreference.fromName('local'), AIProviderPreference.local);
    });
  });

  group('who answers', () {
    const phoneReply =
        '{"corrected":"","explanation":"","reply":"Vom Handy","followUp":"?"}';

    Future<(HybridAIRepository, FakeRuntime, _Cloud)> setup(
      AIProviderPreference pref, {
      Set<String> installed = const {},
      bool hasKey = true,
      Object? cloudError,
      bool server = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final runtime = FakeRuntime(installed: {...installed})
        ..reply = phoneReply;
      final models = ModelManager(runtime);
      await models.ensureLoaded();
      final cloud = _Cloud()..error = cloudError;
      return (
        HybridAIRepository(
          onDevice: OnDeviceAIRepository(models),
          server: _ServerAI(),
          cloud: cloud,
          cloudAvailable: () => hasKey,
          serverEnabled: () => server,
          models: models,
          preference: () => pref,
        ),
        runtime,
        cloud,
      );
    }

    const limited =
        ProviderUnavailableException('Groq', ProviderProblem.rateLimited);

    test('automatic answers on the phone and sends nothing to Groq', () async {
      final (repo, runtime, cloud) = await setup(AIProviderPreference.automatic,
          installed: {'gemma-3-1b'});
      expect((await repo.chat('Hallo', _context)).reply, 'Vom Handy');
      expect(runtime.calls, isNotEmpty);
      expect(cloud.calls, 0);
    });

    test('automatic uses the learner\'s Groq key for what is not downloaded',
        () async {
      final (repo, _, cloud) = await setup(AIProviderPreference.automatic);
      expect((await repo.chat('Hallo', _context)).reply, 'Von Groq');
      expect(cloud.calls, 1);
    });

    test('automatic without a key says what to download', () async {
      final (repo, _, cloud) =
          await setup(AIProviderPreference.automatic, hasKey: false);
      await expectLater(repo.chat('Hallo', _context),
          throwsA(isA<ModelNotInstalledException>()));
      expect(cloud.calls, 0);
    });

    test('phone-only never contacts Groq, even with a key', () async {
      final (repo, _, cloud) = await setup(AIProviderPreference.local);
      await expectLater(repo.chat('Hallo', _context),
          throwsA(isA<ModelNotInstalledException>()));
      expect(cloud.calls, 0);
    });

    test('Groq mode uses Groq even when the phone could answer', () async {
      final (repo, runtime, cloud) =
          await setup(AIProviderPreference.cloud, installed: {'gemma-3-1b'});
      expect((await repo.chat('Hallo', _context)).reply, 'Von Groq');
      expect(runtime.calls, isEmpty);
      expect(cloud.calls, 1);
    });

    test('Groq mode without a key asks for one instead of switching', () async {
      final (repo, runtime, _) = await setup(AIProviderPreference.cloud,
          installed: {'gemma-3-1b'}, hasKey: false);
      await expectLater(
          repo.chat('Hallo', _context),
          throwsA(isA<ProviderUnavailableException>()
              .having((e) => e.problem, 'problem', ProviderProblem.noKey)));
      expect(runtime.calls, isEmpty);
    });

    test(
        'when Groq runs out the learner is told; the phone is NOT used unasked',
        () async {
      final (repo, runtime, _) = await setup(AIProviderPreference.cloud,
          installed: {'gemma-3-1b'}, cloudError: limited);
      await expectLater(repo.chat('Hallo', _context),
          throwsA(isA<ProviderUnavailableException>()));
      expect(runtime.calls, isEmpty);
    });

    test('after the learner agrees, the same request is answered on the phone',
        () async {
      final (repo, runtime, cloud) = await setup(AIProviderPreference.cloud,
          installed: {'gemma-3-1b'}, cloudError: limited);
      final reply = await runOnPhone(() => repo.chat('Hallo', _context));
      expect(reply.reply, 'Vom Handy');
      expect(runtime.calls, isNotEmpty);
      expect(cloud.calls, 0);
      // The choice covers that request only.
      await expectLater(repo.chat('Hallo', _context),
          throwsA(isA<ProviderUnavailableException>()));
    });

    test('speech recognition follows the same rules', () async {
      final (repo, _, cloud) =
          await setup(AIProviderPreference.cloud, installed: {'whisper-base'});
      const audio =
          AudioCapture(bytes: [1], filename: 'a.wav', mimeType: 'audio/wav');
      expect((await repo.transcribeAudio(audio, _context)).text, 'von groq');
      expect(cloud.calls, 1);
    });

    test('voices are never sent to Groq', () async {
      final (repo, runtime, cloud) = await setup(AIProviderPreference.cloud,
          installed: {'de_DE-thorsten-medium'});
      final audio = await repo.synthesizeSpeech('Hallo', _context);
      expect(audio.bytes, isNotEmpty);
      expect(runtime.calls.single, startsWith('speak:'));
      expect(cloud.calls, 0);
    });

    test('the developer server is only used when switched on', () async {
      final (off, _, _) =
          await setup(AIProviderPreference.automatic, hasKey: false);
      await expectLater(off.chat('Hallo', _context),
          throwsA(isA<ModelNotInstalledException>()));
      final (on, _, _) = await setup(AIProviderPreference.automatic,
          hasKey: false, server: true);
      expect((await on.chat('Hallo', _context)).reply, 'Vom Server');
    });
  });

  group('the key screen', () {
    late MemorySecretStore store;
    late List<String> checked;
    ProviderProblem? checkResult;

    Future<void> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      store = MemorySecretStore();
      checked = [];
      checkResult = null;
      tester.view.physicalSize = const Size(700, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          cloudAISettingsProvider
              .overrideWith((ref) => CloudAISettings(store: store)),
          cloudKeyCheckerProvider.overrideWithValue((provider, key, url) async {
            checked.add('${provider.id}:$key');
            return checkResult;
          }),
        ],
        child: MaterialApp(
          theme: SprichstTheme.light,
          home: const Scaffold(
              body: SingleChildScrollView(child: CloudProviderSection())),
        ),
      ));
      await tester.pump();
    }

    testWidgets('a good key is checked, saved and then shown only masked',
        (tester) async {
      await pump(tester);
      await tester.enterText(
          find.byKey(const ValueKey('cloud-key-field')), _key);
      await tester.tap(find.byKey(const ValueKey('cloud-save')));
      await tester.pumpAndSettle();

      expect(checked, ['groq:$_key']);
      expect(store.values.values, [_key]);
      expect(find.byKey(const ValueKey('cloud-key-status')), findsOneWidget);
      expect(find.textContaining(_key), findsNothing);
      expect(find.textContaining('Connected'), findsOneWidget);
      // The box is emptied so the key is not left lying on screen.
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('cloud-key-field')))
              .controller!
              .text,
          isEmpty);
    });

    testWidgets('the field hides what is typed', (tester) async {
      await pump(tester);
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('cloud-key-field')))
              .obscureText,
          isTrue);
    });

    testWidgets('something that is not a key is refused without a network call',
        (tester) async {
      await pump(tester);
      await tester.enterText(
          find.byKey(const ValueKey('cloud-key-field')), 'hello there');
      await tester.tap(find.byKey(const ValueKey('cloud-save')));
      await tester.pumpAndSettle();
      expect(checked, isEmpty);
      expect(store.values, isEmpty);
      expect(
          find.textContaining('does not look like an API key'), findsOneWidget);
    });

    testWidgets('a key Groq rejects is not saved', (tester) async {
      await pump(tester);
      checkResult = ProviderProblem.invalidKey;
      await tester.enterText(
          find.byKey(const ValueKey('cloud-key-field')), _key);
      await tester.tap(find.byKey(const ValueKey('cloud-save')));
      await tester.pumpAndSettle();
      expect(store.values, isEmpty);
      expect(find.textContaining('did not accept'), findsOneWidget);
    });

    testWidgets('offline, a well-formed key is kept and checked on first use',
        (tester) async {
      await pump(tester);
      checkResult = ProviderProblem.offline;
      await tester.enterText(
          find.byKey(const ValueKey('cloud-key-field')), _key);
      await tester.tap(find.byKey(const ValueKey('cloud-save')));
      await tester.pumpAndSettle();
      expect(store.values.values, [_key]);
      expect(find.textContaining('could not be reached'), findsOneWidget);
    });

    testWidgets('removing the key asks first, then deletes it', (tester) async {
      await pump(tester);
      await tester.enterText(
          find.byKey(const ValueKey('cloud-key-field')), _key);
      await tester.tap(find.byKey(const ValueKey('cloud-save')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cloud-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Remove your Groq key?'), findsOneWidget);
      await tester.tap(find.text('Remove key'));
      await tester.pumpAndSettle();
      expect(store.values, isEmpty);
      expect(find.byKey(const ValueKey('cloud-key-status')), findsNothing);
    });

    testWidgets('the model can be chosen', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.text('Llama 3.1 8B (more messages)'));
      await tester.tap(find.text('Llama 3.1 8B (more messages)'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
          tester.element(find.byType(CloudProviderSection)));
      expect(container.read(cloudAISettingsProvider).model,
          'llama-3.1-8b-instant');
    });
  });
}

/// A stand-in Groq that counts its calls.
class _Cloud extends MockAIRepository {
  int calls = 0;
  Object? error;

  @override
  Future<TutorReply> chat(String message, TutorContext context) async {
    calls++;
    if (error != null) throw error!;
    return const TutorReply(reply: 'Von Groq', followUp: '?');
  }

  @override
  Future<TranscriptionResult> transcribeAudio(
      AudioCapture audio, TutorContext context) async {
    calls++;
    if (error != null) throw error!;
    return const TranscriptionResult(text: 'von groq', language: 'de');
  }
}

class _ServerAI extends MockAIRepository {
  @override
  Future<TutorReply> chat(String message, TutorContext context) async =>
      const TutorReply(reply: 'Vom Server', followUp: '?');
}
