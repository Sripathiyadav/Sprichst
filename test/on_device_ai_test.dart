import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/data/ai/hybrid_ai_repository.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/on_device/model_catalogue.dart';
import 'package:sprichst/data/on_device/model_manager.dart';
import 'package:sprichst/data/on_device/on_device_ai_repository.dart';
import 'package:sprichst/data/on_device/wav.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/on_device_fakes.dart';

class FailingServer extends MockAIRepository {
  @override
  Future<TutorReply> chat(String message, TutorContext context) =>
      throw Exception('SocketException: offline');
}

const context = TutorContext(level: 'A1');

Future<ModelManager> manager(FakeRuntime runtime) async {
  SharedPreferences.setMockInitialValues({});
  final m = ModelManager(runtime);
  await m.ensureLoaded();
  return m;
}

void main() {
  group('catalogue', () {
    test('recommends a bigger tutor the more memory the phone has', () {
      expect(recommendedTutor(2048).id, 'qwen2.5-0.5b');
      expect(recommendedTutor(3800).id, 'gemma-3-1b');
      expect(recommendedTutor(5632).id, 'qwen2.5-1.5b');
      expect(recommendedTutor(7680).id, 'gemma-3-4b');
      expect(recommendedTutor(null).id, 'gemma-3-1b');
    });

    test('flags models too large for the phone', () {
      final big = tutorModels.last;
      expect(fitFor(big, 3800, recommendedTutor(3800)), ModelFit.tight);
      expect(fitFor(big, 7680, recommendedTutor(7680)), ModelFit.recommended);
    });

    test('every voice in the picker can be downloaded', () {
      for (final v in VoiceList.offline.voices.where((v) => v.isOpenSource)) {
        expect(voiceModels, contains(v.id));
      }
    });
  });

  test('WAV encode and decode round-trip', () {
    final samples = Float32List.fromList([0, 0.5, -0.5, 1, -1]);
    final wav = decodeWav(encodeWav(samples, 16000));
    expect(wav.sampleRate, 16000);
    for (var i = 0; i < samples.length; i++) {
      expect(wav.samples[i], closeTo(samples[i], 0.001));
    }
  });

  group('reply parsing', () {
    test('a "correction" identical to the message means no mistake', () {
      final reply = parseTutorReply(
          '{"reply":"Toll!","correction":"Ich gehe heute.","explanation":"x","followUp":"Wohin?"}',
          'Ich gehe heute.');
      expect(reply.correction, isNull);
      expect(reply.explanation, isNull);
    });

    test('a translation is not a correction', () {
      final reply = parseTutorReply(
          '{"reply":"Gut","correction":"I am going to work tomorrow.","explanation":"x","followUp":"?"}',
          'Ich gehen morgen zur Arbeit.');
      expect(reply.correction, isNull);
      final coach = parseCoachReply(
          '{"correct":false,"corrected":"I have a dog.","explanation":"x","followUp":"?"}',
          'Ich habe ein Hund.');
      expect(coach.corrected, 'Ich habe ein Hund.');
    });

    test('empty strings become null and real corrections survive', () {
      expect(
          parseTutorReply(
                  '{"reply":"Gut","correction":"","explanation":"","followUp":"Und du?"}',
                  'Mir geht es gut.')
              .correction,
          isNull);
      final fixed = parseTutorReply(
          '{"reply":"Fast!","correction":"Ich habe einen Hund.","explanation":"accusative","followUp":"Wie heißt er?"}',
          'Ich habe ein Hund.');
      expect(fixed.correction, 'Ich habe einen Hund.');
      // The exact change always leads, then the model's reason.
      expect(fixed.explanation, '"ein" → "einen". accusative');
    });

    test('correctness follows whether the sentence changed', () {
      final same = parseCoachReply(
          '{"correct":false,"corrected":"Ich bin müde.","explanation":"?","followUp":"Warum?"}',
          'Ich bin müde.');
      expect(same.wasCorrect, isTrue);
      final changed = parseCoachReply(
          '{"correct":true,"corrected":"Ich habe einen Hund.","explanation":"ein → einen","followUp":"?"}',
          'Ich habe ein Hund.');
      expect(changed.wasCorrect, isFalse);
      expect(changed.corrected, 'Ich habe einen Hund.');
    });

    test('a change explained as "correct" is described from the diff', () {
      final reply = parseCoachReply(
          '{"correct":false,"corrected":"Ich habe einen Hund.","explanation":"This sentence is correct.","followUp":"?"}',
          'Ich habe ein Hund.');
      expect(reply.explanation, '"ein" → "einen".');
      expect(describeChange('Ich gehen heute.', 'Ich gehe heute.'),
          '"gehen" → "gehe".');
    });
  });

  group('model manager', () {
    test('uses the recommendation until the learner picks', () async {
      final m = await manager(FakeRuntime(ram: 3800));
      expect(m.selectedTutor.id, 'gemma-3-1b');
      await m.selectTutor('qwen2.5-0.5b');
      expect(m.selectedTutor.id, 'qwen2.5-0.5b');
    });

    test('simulators are not recommended models they cannot run quickly',
        () async {
      final m = await manager(FakeRuntime(ram: 8192)..simulator = true);
      expect(m.recommendedTutorModel.id, 'gemma-3-1b');
    });

    test('falls back to any installed tutor', () async {
      final m = await manager(FakeRuntime(installed: {'qwen2.5-0.5b'}));
      expect(m.activeTutor?.id, 'qwen2.5-0.5b');
    });

    test('download success, failure message and delete', () async {
      final runtime = FakeRuntime();
      final m = await manager(runtime);
      expect(await m.download('whisper-tiny'), isTrue);
      expect(m.isInstalled('whisper-tiny'), isTrue);

      runtime.downloadError = Exception('SocketException: Failed host lookup');
      expect(await m.download('whisper-base'), isFalse);
      expect(m.errors['whisper-base'], contains('No internet'));
      expect(m.isDownloading('whisper-base'), isFalse);

      await m.delete('whisper-tiny');
      expect(m.isInstalled('whisper-tiny'), isFalse);
    });
  });

  group('on-device repository', () {
    test('chat runs on the active tutor', () async {
      final runtime = FakeRuntime(installed: {'qwen2.5-1.5b'})
        ..reply =
            '{"reply":"Hallo!","correction":"","explanation":"","followUp":"Wie geht es dir?"}';
      final repo = OnDeviceAIRepository(await manager(runtime));
      final reply = await repo.chat('Hallo', context);
      expect(reply.reply, 'Hallo!');
      expect(runtime.calls, ['generate:qwen2.5-1.5b']);
    });

    test('says what to download when nothing is installed', () async {
      final repo = OnDeviceAIRepository(await manager(FakeRuntime()));
      expect(() => repo.chat('Hallo', context),
          throwsA(isA<ModelNotInstalledException>()));
    });

    test('speaks with an installed voice when the chosen one is missing',
        () async {
      final runtime = FakeRuntime(installed: {'de_DE-kerstin-low'});
      final repo = OnDeviceAIRepository(await manager(runtime));
      final audio = await repo.synthesizeSpeech('Hallo', context,
          voice: 'de_DE-ramona-low', speechRate: 180);
      expect(audio.voiceUsed, 'de_DE-kerstin-low');
      expect(audio.usedFallback, isTrue);
      expect(runtime.calls.single, 'speak:de_DE-kerstin-low:1.0');
    });

    test('transcribes with Whisper on the phone', () async {
      final runtime = FakeRuntime(installed: {'whisper-base'});
      final repo = OnDeviceAIRepository(await manager(runtime));
      final result = await repo.transcribeAudio(
          const AudioCapture(
              bytes: [1], filename: 'a.wav', mimeType: 'audio/wav'),
          context);
      expect(result.text, 'Ich habe ein Hund');
    });
  });

  group('hybrid routing', () {
    Future<(HybridAIRepository, FakeRuntime)> hybrid(
        AIProviderPreference pref, Set<String> installed,
        {MockAIRepository? server}) async {
      final runtime = FakeRuntime(installed: installed)
        ..reply =
            '{"reply":"Vom Handy","correction":"","explanation":"","followUp":"?"}';
      final m = await manager(runtime);
      return (
        HybridAIRepository(
          onDevice: OnDeviceAIRepository(m),
          server: server ?? MockAIRepository(),
          models: m,
          preference: () => pref,
        ),
        runtime,
      );
    }

    test('automatic prefers the phone', () async {
      final (repo, runtime) =
          await hybrid(AIProviderPreference.automatic, {'gemma-3-1b'});
      expect((await repo.chat('Hallo', context)).reply, 'Vom Handy');
      expect(runtime.calls, isNotEmpty);
    });

    test('automatic uses the server for what is not downloaded', () async {
      final (repo, runtime) = await hybrid(AIProviderPreference.automatic, {});
      expect((await repo.chat('Hallo', context)).reply, isNot('Vom Handy'));
      expect(runtime.calls, isEmpty);
    });

    test('phone-only never calls the server', () async {
      final (repo, _) = await hybrid(AIProviderPreference.local, {});
      expect(() => repo.chat('Hallo', context),
          throwsA(isA<ModelNotInstalledException>()));
    });

    test('server-first falls back to the phone when offline', () async {
      final (repo, _) = await hybrid(AIProviderPreference.groq, {'gemma-3-1b'},
          server: FailingServer());
      expect((await repo.chat('Hallo', context)).reply, 'Vom Handy');
    });
  });
}
