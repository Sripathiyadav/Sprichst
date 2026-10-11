import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';

const _wide = Size(900, 1000);

LearningProfile _learner() => LearningProfile.newLearner(
    nativeLanguage: 'English', currentLevel: CefrLevel.a1);

Future<InMemoryLearningRepository> _openVoiceSettings(
  WidgetTester tester, {
  LearningProfile? profile,
  Brightness brightness = Brightness.light,
}) async {
  final repository = InMemoryLearningRepository(profile ?? _learner());
  await pumpSprichst(tester,
      size: _wide, brightness: brightness, repository: repository);
  await tester.tap(find.text('Account').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('AI & voice').first);
  await tester.pumpAndSettle();
  return repository;
}

/// Scrolls the settings page until [target] is on screen.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
            of: find.byType(SettingsPage), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('VoiceList', () {
    test('the offline list matches what the gateway offers', () {
      final ids = VoiceList.offline.voices.map((v) => v.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, contains(defaultVoiceId));
      expect(VoiceList.offline.voices.every((v) => v.isOpenSource), isTrue);
      // Non-commercial voices are not offered.
      expect(ids.any((id) => id.contains('pavoque')), isFalse);
    });

    test('parses the gateway listing and finds legacy voice names', () {
      final list = VoiceList.fromJson({
        'default': 'de_DE-kerstin-low',
        'voices': [
          {
            'id': 'de_DE-kerstin-low',
            'label': 'Kerstin',
            'engine': 'piper',
            'description': 'Light voice',
            'license': 'CC0',
            'quality': 'low',
            'available': true,
          },
          {
            'id': 'system-anna',
            'label': 'Anna (system)',
            'engine': 'system',
            'description': 'Built in',
            'available': true,
          },
        ],
      });
      expect(list.defaultId, 'de_DE-kerstin-low');
      expect(list.find('de_DE-kerstin-low')!.available, isTrue);
      expect(list.find('Anna')!.id, 'system-anna'); // stored by older versions
      expect(list.find('nobody'), isNull);
      expect(list.labelOf('nobody'), 'nobody');
    });
  });

  testWidgets('the voice settings list the open-source voices', (tester) async {
    await _openVoiceSettings(tester);
    await _reveal(tester, find.textContaining('German voices'));
    expect(find.textContaining('German voices'), findsOneWidget);
    for (final name in ['Thorsten', 'Kerstin', 'Ramona', 'Karlsson', 'Eva']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.textContaining('CC0'), findsWidgets);
  });

  testWidgets('choosing a voice saves it', (tester) async {
    final repository = await _openVoiceSettings(tester);
    expect(repository.profile!.voice, defaultVoiceId);
    await _reveal(tester, find.text('Kerstin'));
    await tester.tap(find.text('Kerstin'));
    await tester.pumpAndSettle();
    expect(repository.profile!.voice, 'de_DE-kerstin-low');
  });

  testWidgets('a voice that is not on the phone can be downloaded',
      (tester) async {
    await _openVoiceSettings(tester);
    await _reveal(tester, find.byTooltip('Download Kerstin'));
    expect(find.textContaining('Not downloaded · 67 MB'), findsWidgets);
    await tester.tap(find.byTooltip('Download Kerstin'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Preview Kerstin'), findsOneWidget);
  });

  testWidgets('the pause before your turn ends can be changed', (tester) async {
    final repository = await _openVoiceSettings(tester);
    expect(repository.profile!.voicePauseMs, defaultVoicePauseMs);
    await _reveal(tester, find.text('Long'));
    await tester.tap(find.text('Long'));
    await tester.pumpAndSettle();
    expect(repository.profile!.voicePauseMs, 1800);
  });

  for (final brightness in Brightness.values) {
    testWidgets('voice settings are accessible in ${brightness.name} mode',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _openVoiceSettings(tester, brightness: brightness);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
