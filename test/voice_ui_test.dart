import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/features/ai_coach/voice/voice_mode_view.dart';
import 'package:sprichst/features/ai_coach/voice/voice_session.dart';

import 'support/fakes.dart';
import 'support/voice_fakes.dart';

const _phone = Size(390, 844);

Future<void> _pumpVoiceMode(
  WidgetTester tester,
  Harness harness, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // The session's async work runs in real time, outside the widget tester's
  // fake clock, so it is started first and the view then joins it.
  await tester.runAsync(harness.begin);
  await tester.pumpWidget(ProviderScope(
    overrides: testOverrides(InMemoryLearningRepository()),
    child: MaterialApp(
      theme: brightness == Brightness.light
          ? SprichstTheme.light
          : SprichstTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => VoiceModeView(session: harness.session),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Plays a spoken turn into the fake microphone. Real time has to pass for the
/// widget tree to see the changes, so each step is followed by a pump.
Future<void> _say(WidgetTester tester, Harness h) async {
  await tester.runAsync(() async {
    await h.sound(quietDb, 500);
    await h.sound(speechDb, 1000);
    await h.sound(quietDb, 1500);
  });
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('voice mode listens, shows the exchange and speaks the reply',
      (tester) async {
    final h = Harness();
    await _pumpVoiceMode(tester, h);
    expect(find.text('Listening…'), findsOneWidget);
    expect(find.text('Voice mode'), findsOneWidget);

    await _say(tester, h);
    expect(find.text('Your tutor is speaking'), findsOneWidget);
    expect(find.text('Hallo, wie geht es dir?'), findsOneWidget);
    expect(find.textContaining('Mir geht es gut!'), findsWidgets);

    // The reply ends and it listens again without a tap.
    await tester.runAsync(() async {
      h.output.playing!.complete();
      await pumpEventQueue();
    });
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Listening…'), findsOneWidget);
    expect(h.recorder.starts, 2);
    await tester.runAsync(h.session.stop);
  });

  testWidgets('the microphone button pauses and resumes', (tester) async {
    final h = Harness();
    await _pumpVoiceMode(tester, h);
    await tester.tap(find.byTooltip('Pause listening'));
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byTooltip('Resume listening'), findsOneWidget);

    await tester.tap(find.byTooltip('Resume listening'));
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    expect(find.text('Listening…'), findsOneWidget);
    await tester.runAsync(h.session.stop);
  });

  testWidgets('skip is only available while the tutor is speaking',
      (tester) async {
    final h = Harness();
    await _pumpVoiceMode(tester, h);
    IconButton skip() => tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.skip_next_rounded),
        matching: find.byType(IconButton)));
    expect(skip().onPressed, isNull);
    await _say(tester, h);
    expect(skip().onPressed, isNotNull);
    await tester.runAsync(h.session.stop);
  });

  testWidgets('ending returns the conversation to the caller', (tester) async {
    final h = Harness();
    List<VoiceTurn>? returned;
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(h.begin);
    await tester.pumpWidget(ProviderScope(
      overrides: testOverrides(InMemoryLearningRepository()),
      child: MaterialApp(
        theme: SprichstTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => returned = await Navigator.of(context)
                .push<List<VoiceTurn>>(MaterialPageRoute(
                    builder: (_) => VoiceModeView(session: h.session))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
    await _say(tester, h);
    await tester.tap(find.byTooltip('End conversation').last);
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump(const Duration(milliseconds: 400));
    expect(returned, hasLength(1));
    expect(returned!.single.user, 'Hallo, wie geht es dir?');
  });

  for (final brightness in Brightness.values) {
    testWidgets('voice mode is accessible in ${brightness.name} mode',
        (tester) async {
      final handle = tester.ensureSemantics();
      final h = Harness();
      await _pumpVoiceMode(tester, h, brightness: brightness);
      await _say(tester, h);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.runAsync(h.session.stop);
      handle.dispose();
    });
  }

  testWidgets('an unavailable microphone is explained, not silent',
      (tester) async {
    final h = Harness();
    h.recorder.allowed = false;
    await _pumpVoiceMode(tester, h);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.textContaining('Microphone access is off'), findsOneWidget);
  });
}
