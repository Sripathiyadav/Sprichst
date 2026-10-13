import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/data/ai/cloud_ai_repository.dart';
import 'package:sprichst/data/ai/cloud_ai_settings.dart';
import 'package:sprichst/data/ai/cloud_providers.dart';
import 'package:sprichst/data/ai/hybrid_ai_repository.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/on_device/model_manager.dart';
import 'package:sprichst/data/on_device/on_device_ai_repository.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';
import 'support/on_device_fakes.dart';

Future<(HybridAIRepository, List<http.Request>)> _setup(
  AIProviderPreference pref, {
  bool key = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = CloudAISettings(
      store: MemorySecretStore({
    if (key)
      CloudAISettings.keyNameOf('groq'): 'gsk_' 'AbCdEfGhIjKlMnOpQrSt123456',
  }));
  await settings.load();
  final seen = <http.Request>[];
  final cloud = CloudAIRepository(
      settings: settings,
      client: MockClient((request) async {
        seen.add(request);
        return http.Response('{}', 200);
      }));
  final models = ModelManager(FakeRuntime());
  await models.ensureLoaded();
  return (
    HybridAIRepository(
      onDevice: OnDeviceAIRepository(models),
      server: MockAIRepository(),
      cloud: cloud,
      cloudAvailable: () => settings.isConfigured,
      serverEnabled: () => false,
      models: models,
      preference: () => pref,
    ),
    seen,
  );
}

void main() {
  test('choosing the own key connects ahead, asking only for the model list',
      () async {
    final (repo, seen) = await _setup(AIProviderPreference.cloud);
    await repo.warmUp();
    expect(seen, hasLength(1));
    expect(seen.single.method, 'GET');
    expect(seen.single.url.path, endsWith('/models'));
    expect(seen.single.url.host, Uri.parse(CloudProvider.groq.baseUrl).host);
    expect(seen.single.body, isEmpty, reason: 'no message text is sent');
  });

  test('other modes, or no key, contact nobody', () async {
    for (final pref in [
      AIProviderPreference.automatic,
      AIProviderPreference.local
    ]) {
      final (repo, seen) = await _setup(pref);
      await repo.warmUp();
      expect(seen, isEmpty, reason: pref.name);
    }
    final (repo, seen) = await _setup(AIProviderPreference.cloud, key: false);
    await repo.warmUp();
    expect(seen, isEmpty);
  });

  test('a failure is swallowed: the first real message reports problems',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = CloudAISettings(
        store: MemorySecretStore({
      CloudAISettings.keyNameOf('groq'): 'gsk_' 'AbCdEfGhIjKlMnOpQrSt123456',
    }));
    await settings.load();
    final cloud = CloudAIRepository(
        settings: settings,
        client: MockClient((_) async => throw http.ClientException('offline')));
    await cloud.warmUp(); // must not throw
  });
}
