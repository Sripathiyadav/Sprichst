import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/account/account_view.dart';

import 'support/fakes.dart';

LearningProfile _profile() => LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.a1)
        .copyWith(
      xp: 120,
      streak: 4,
      lastStudyDate: DateTime.now(),
      lessonProgress: const {
        'pre_a1_greetings': LessonProgress(status: LessonStatus.completed),
      },
    );

Future<void> _openAccount(WidgetTester tester) async {
  await tester.tap(find.text('Account').last);
  await tester.pumpAndSettle();
}

/// Scrolls the Account list until [finder] is built and on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
            of: find.byType(AccountView), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('contact page emails the developer and links their profiles',
      (tester) async {
    final opened = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      opened.add((call.arguments as Map)['url'] as String);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await pumpSprichst(tester,
        size: const Size(1200, 900),
        brightness: Brightness.light,
        repository: InMemoryLearningRepository(_profile()));
    await _openAccount(tester);

    await _reveal(tester, find.text('Contact developer'));
    await tester.tap(find.text('Contact developer'));
    await tester.pumpAndSettle();

    final send = find.widgetWithText(FilledButton, 'Send by email');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'The streak looks wrong.');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();

    final mail = Uri.parse(opened.single);
    expect(mail.scheme, 'mailto');
    expect(mail.path, 'sripathiyadav66@gmail.com');
    expect(mail.queryParameters['subject'], contains('Report a problem'));
    expect(mail.queryParameters['body'], contains('The streak looks wrong.'));
    expect(mail.queryParameters['body'], contains('Level A1'));

    for (final name in ['LinkedIn', 'Instagram', 'GitHub']) {
      await tester.ensureVisible(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    expect(opened.skip(1), [
      'https://www.linkedin.com/in/sripathi-yadav/',
      'https://www.instagram.com/sri.in.germany/',
      'https://github.com/Sripathiyadav',
    ]);
  });

  testWidgets('signing out asks first', (tester) async {
    final auth = FakeAuthRepository();
    await pumpSprichst(tester,
        size: const Size(1200, 900),
        brightness: Brightness.light,
        repository: InMemoryLearningRepository(_profile()),
        auth: auth);
    await _openAccount(tester);
    await _reveal(tester, find.text('Sign out'));

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last); // the dialog's button
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
  });

  testWidgets('export copies the profile as JSON', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpSprichst(tester,
        size: const Size(1200, 900),
        brightness: Brightness.light,
        repository: InMemoryLearningRepository(_profile()));
    await _openAccount(tester);

    await _reveal(tester, find.text('Privacy & data'));
    await tester.tap(find.text('Privacy & data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export my data'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final exported = jsonDecode(copied!) as Map<String, dynamic>;
    expect(exported['xp'], 120);
    expect(exported['lessonProgress'], contains('pre_a1_greetings'));
  });

  testWidgets('reset learning progress clears progress but keeps settings',
      (tester) async {
    final repository = InMemoryLearningRepository(
      _profile().copyWith(appearancePreference: AppearancePreference.dark),
    );
    await pumpSprichst(tester,
        size: const Size(1200, 900),
        brightness: Brightness.light,
        repository: repository);
    await _openAccount(tester);

    final reset = find.text('Reset learning progress');
    await _reveal(tester, reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();

    final saved = repository.profile!;
    expect(saved.xp, 0);
    expect(saved.lessonProgress, isEmpty);
    expect(saved.appearancePreference, AppearancePreference.dark);
  });

  testWidgets('cancelling the reset dialog changes nothing', (tester) async {
    final repository = InMemoryLearningRepository(_profile());
    await pumpSprichst(tester,
        size: const Size(1200, 900),
        brightness: Brightness.light,
        repository: repository);
    await _openAccount(tester);

    final reset = find.text('Reset learning progress');
    await _reveal(tester, reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.profile!.xp, 120);
  });

  testWidgets('profile name edits persist', (tester) async {
    final repository = InMemoryLearningRepository(_profile());
    await pumpSprichst(tester,
        size: const Size(1200, 900),
        brightness: Brightness.light,
        repository: repository);
    await _openAccount(tester);

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sam');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(repository.profile!.name, 'Sam');
  });
}
