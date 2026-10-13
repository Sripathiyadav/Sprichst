import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/cloud_ai_settings.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/account/web_ai_notice.dart';

import 'support/fakes.dart';
import 'support/on_device_fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool browser,
  bool key = false,
  Size size = const Size(390, 1800),
}) async {
  SharedPreferences.setMockInitialValues({});
  await pumpSprichst(tester,
      size: size,
      brightness: Brightness.light,
      repository: InMemoryLearningRepository(LearningProfile.newLearner(
          nativeLanguage: 'English', currentLevel: CefrLevel.a1)),
      extraOverrides: [
        onDeviceRuntimeProvider
            .overrideWithValue(FakeRuntime()..supported = !browser),
        cloudAISettingsProvider.overrideWith((ref) => CloudAISettings(
                store: MemorySecretStore({
              if (key)
                CloudAISettings.keyNameOf('groq'):
                    'gsk_' 'AbCdEfGhIjKlMnOpQrSt123456',
            }))
              ..load()),
      ]);
  await tester.pumpAndSettle();
}

void main() {
  final notice = find.byKey(const ValueKey('web-ai-notice'));

  testWidgets('in a browser without a key, Home says there is no local model',
      (tester) async {
    await _pump(tester, browser: true);
    expect(notice, findsOneWidget);
    expect(find.text(WebAiNotice.title), findsOneWidget);
    expect(find.textContaining('add your own AI key'), findsOneWidget);
  });

  testWidgets('the Coach and the Translator say it too', (tester) async {
    await _pump(tester, browser: true);
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(notice, findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('home-translator'));
    for (var i = 0; i < 20 && tile.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(notice, findsOneWidget);
    expect(find.text('German and English'), findsOneWidget);
  });

  testWidgets('"Add my AI key" opens AI & voice', (tester) async {
    await _pump(tester, browser: true);
    await tester.tap(find.text('Add my AI key'));
    await tester.pumpAndSettle();
    expect(find.text('AI & voice'), findsOneWidget);
  });

  testWidgets('once a key is saved the notice is gone', (tester) async {
    await _pump(tester, browser: true, key: true);
    expect(notice, findsNothing);
  });

  testWidgets('in the phone and desktop apps there is no notice',
      (tester) async {
    await _pump(tester, browser: false);
    expect(notice, findsNothing);
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
  });
}
