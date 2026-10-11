import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/hybrid_ai_repository.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/on_device/on_device_ai_repository.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/domain/repositories/ai_exceptions.dart';

import 'support/fakes.dart';
import 'support/on_device_fakes.dart';

/// A Groq that has run out of allowance.
class _LimitedGroq extends MockAIRepository {
  int calls = 0;

  @override
  Future<TutorReply> chat(String message, TutorContext context) async {
    calls++;
    throw const ProviderUnavailableException(
        'Groq', ProviderProblem.rateLimited,
        retryAfter: Duration(minutes: 5));
  }
}

void main() {
  testWidgets(
      'when the Groq limit is reached the coach says so and offers the phone; '
      'only a tap sends the message there', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final runtime = FakeRuntime(installed: {'gemma-3-1b'})
      ..reply =
          '{"corrected":"","explanation":"","reply":"Hallo vom Handy!","followUp":"Wo wohnst du?"}';
    final groq = _LimitedGroq();
    final repository = InMemoryLearningRepository(
      LearningProfile.newLearner(
              nativeLanguage: 'English', currentLevel: CefrLevel.a1)
          .copyWith(aiProviderPreference: AIProviderPreference.groq),
    );

    await pumpSprichst(
      tester,
      size: const Size(390, 844),
      brightness: Brightness.light,
      repository: repository,
      extraOverrides: [
        onDeviceRuntimeProvider.overrideWithValue(runtime),
        aiRepositoryProvider.overrideWith((ref) {
          final models = ref.read(modelManagerProvider);
          return HybridAIRepository(
            onDevice: OnDeviceAIRepository(models),
            server: MockAIRepository(),
            groq: groq,
            groqAvailable: () => true,
            serverEnabled: () => false,
            models: models,
          );
        }),
      ],
    );

    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hallo');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // Told what happened, offered the phone, and nothing has been answered yet.
    expect(find.textContaining('reached your Groq limit'), findsOneWidget);
    expect(find.text('Answer on this phone'), findsOneWidget);
    expect(find.textContaining('Hallo vom Handy'), findsNothing);
    expect(runtime.calls.where((c) => c.startsWith('generate')), isEmpty);
    expect(groq.calls, 1);

    await tester.tap(find.text('Answer on this phone'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hallo vom Handy'), findsOneWidget);
    expect(runtime.calls.where((c) => c.startsWith('generate')), isNotEmpty);
    expect(groq.calls, 1, reason: 'the phone answer must not ask Groq again');
  });
}
