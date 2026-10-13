import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/data/ai/hybrid_ai_repository.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/on_device/model_manager.dart';
import 'package:sprichst/data/on_device/on_device_ai_repository.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/domain/repositories/ai_exceptions.dart';

import 'support/on_device_fakes.dart';

class _Counting extends MockAIRepository {
  int calls = 0;

  @override
  Future<String> translate(String text, TranslationDirection direction) async {
    calls++;
    return 'ok';
  }
}

void main() {
  tearDown(() => ProviderUnavailableException.inBrowser = false);

  group('messages in a browser', () {
    const noKey = ProviderUnavailableException('Groq', ProviderProblem.noKey);

    test('ask for a key and never point to the phone', () {
      ProviderUnavailableException.inBrowser = true;
      expect(noKey.toString(), contains('Add your Groq key'));
      expect(noKey.toString(), contains('web browser'));
      expect(noKey.toString(), isNot(contains('This phone only')));
      for (final problem in ProviderProblem.values) {
        final e = ProviderUnavailableException('Groq', problem);
        expect(e.toString(), isNot(contains('on this phone')),
            reason: problem.name);
        expect(e.canOfferPhone, isFalse, reason: problem.name);
      }
    });

    test('on a phone the old advice stays', () {
      expect(noKey.toString(), contains('This phone only'));
      expect(
          const ProviderUnavailableException('Groq', ProviderProblem.offline)
              .canOfferPhone,
          isTrue);
    });
  });

  group('"This phone only" in a browser', () {
    Future<(HybridAIRepository, _Counting)> setup(
        AIProviderPreference pref) async {
      SharedPreferences.setMockInitialValues({});
      final models = ModelManager(FakeRuntime()..supported = false);
      await models.ensureLoaded();
      final cloud = _Counting();
      return (
        HybridAIRepository(
          onDevice: OnDeviceAIRepository(models),
          server: MockAIRepository(),
          cloud: cloud,
          cloudAvailable: () => true,
          serverEnabled: () => false,
          models: models,
          preference: () => pref,
        ),
        cloud,
      );
    }

    test('sends nothing anywhere, even with a key, and says why', () async {
      final (repo, cloud) = await setup(AIProviderPreference.local);
      await expectLater(
          repo.translate('Hallo', TranslationDirection.germanToEnglish),
          throwsA(isA<LocalModelsUnavailableException>()));
      expect(cloud.calls, 0);
      expect(const LocalModelsUnavailableException().toString(),
          contains('web browser'));
    });

    test('the other modes still use the key', () async {
      for (final pref in [
        AIProviderPreference.automatic,
        AIProviderPreference.cloud
      ]) {
        final (repo, cloud) = await setup(pref);
        expect(
            await repo.translate('Hallo', TranslationDirection.germanToEnglish),
            'ok');
        expect(cloud.calls, 1, reason: pref.name);
      }
    });
  });
}
