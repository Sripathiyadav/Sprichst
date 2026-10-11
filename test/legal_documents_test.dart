import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/legal/legal_documents.dart';
import 'package:sprichst/features/legal/legal_view.dart';
import 'package:sprichst/features/legal/markdown_lite.dart';

String _read(String path) => File(path).readAsStringSync();

Widget _app(Widget home) => MaterialApp(
      theme: SprichstTheme.build(Brightness.light),
      home: home,
    );

void main() {
  group('markdown reader', () {
    test('reads headings, paragraphs, lists and rules', () {
      final blocks = parseMarkdown('''
# Title

First line
second line

## Part
- one
- two
1. first
2. second

---
''');
      expect(blocks[0], isA<MdHeading>().having((b) => b.level, 'level', 1));
      expect(plainText((blocks[1] as MdParagraph).spans),
          'First line\nsecond line');
      expect(blocks[2], isA<MdHeading>().having((b) => b.level, 'level', 2));
      expect(blocks.whereType<MdListItem>().map((b) => b.marker),
          ['•', '•', '1.', '2.']);
      expect(blocks.last, isA<MdRule>());
    });

    test('reads inline bold, code and placeholders', () {
      expect(parseInline('a **b** `c` [[D_E]] f'), const [
        MdSpan('a '),
        MdSpan('b', bold: true),
        MdSpan(' '),
        MdSpan('c', code: true),
        MdSpan(' '),
        MdSpan('[[D_E]]', placeholder: true),
        MdSpan(' f'),
      ]);
    });

    test('reads a table with its header and rows', () {
      final table = parseMarkdown('''
| Name | Use |
|---|---|
| Roboto | Font |
| Piper | Voice |

after
''');
      final t = table.first as MdTable;
      expect(t.headers.map(plainText), ['Name', 'Use']);
      expect(t.rows.map((r) => r.map(plainText).toList()), [
        ['Roboto', 'Font'],
        ['Piper', 'Voice']
      ]);
      expect(table.last, isA<MdParagraph>());
    });

    test('shows raw markup as text and never as a link or image', () {
      final blocks = parseMarkdown(
          '![x](https://example.com/a.png) [y](https://example.com)');
      expect(plainText((blocks.single as MdParagraph).spans),
          '![x](https://example.com/a.png) [y](https://example.com)');
    });
  });

  group('documents are wired up', () {
    final pubspec = _read('pubspec.yaml');

    test('every listed document exists and is bundled as an asset', () {
      for (final doc in legalDocuments) {
        expect(File(doc.asset).existsSync(), isTrue, reason: doc.asset);
        expect(pubspec, contains('- ${doc.asset}'), reason: doc.asset);
      }
    });

    test('every user-facing document in legal/ is listed in the app', () {
      final listed = legalDocuments.map((d) => d.asset).toSet();
      final onDisk = Directory('legal')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.endsWith('.md') && !p.endsWith('README.md'));
      expect(onDisk.toSet(), listed);
    });

    test('internal records are never bundled', () {
      final assets = [
        for (final line in pubspec.split('\n'))
          if (line.trim().startsWith('- legal')) line.trim(),
      ];
      expect(assets, isNotEmpty);
      expect(assets.any((a) => a.contains('internal')), isFalse);
      expect(assets.any((a) => a.endsWith('README.md')), isFalse);
      expect(assets.any((a) => a.endsWith('/')), isFalse);
    });

    test('titles and ids are unique', () {
      expect(
          {for (final d in legalDocuments) d.id}.length, legalDocuments.length);
      expect({for (final d in legalDocuments) d.title}.length,
          legalDocuments.length);
    });
  });

  group('documents say what the app does', () {
    final privacy = _read('legal/privacy-policy.md');

    test('the menu labels named in the documents exist in the app', () {
      final docs = [
        for (final doc in legalDocuments) _read(doc.asset),
      ].join('\n');
      final appText = [
        for (final f in Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')))
          f.readAsStringSync(),
      ].join('\n');
      for (final label in [
        'Privacy & data',
        'Export my data',
        'Danger zone',
        'Delete account',
        'Reset learning progress',
        'AI & voice',
        'Contact developer',
        'Appearance',
      ]) {
        expect(docs, contains(label),
            reason: '"$label" is no longer in legal/');
        expect(appText, contains("'$label'"),
            reason: '"$label" is named in legal/ but not in the app');
      }
      expect(AIProviderPreference.local.label, 'This phone only');
      expect(privacy, contains('This phone only'));
    });

    test('the privacy policy covers what the law requires it to', () {
      for (final needed in [
        'Who is responsible',
        'legal basis',
        'Who receives your data',
        'Transfers outside your country',
        'How long we keep data',
        'Your rights',
        'Children',
        'Security',
        'complain',
        'California',
        'Brazil',
        'India',
        'Standard Contractual Clauses',
      ]) {
        expect(privacy.toLowerCase(), contains(needed.toLowerCase()),
            reason: needed);
      }
    });

    test('no document claims analytics or tracking is used', () {
      final cookies = _read('legal/cookies-and-storage.md');
      expect(cookies, contains('No analytics'));
      expect(cookies, contains('No session replay'));
      expect(cookies, contains('No Google Fonts'));
    });

    test('exam brands are described as not affiliated', () {
      final disclaimer = _read('legal/disclaimer.md');
      expect(disclaimer, contains('Goethe'));
      expect(disclaimer, contains('TestDaF'));
      expect(disclaimer, contains('not affiliated'));
    });

    test('the takedown page names a designated agent and the DMCA elements',
        () {
      final copyright = _read('legal/copyright-and-takedown.md');
      expect(copyright, contains('designated copyright agent'));
      expect(copyright, contains('512(c)'));
      expect(copyright, contains('Counter-notice'));
      expect(copyright, contains('penalty of perjury'));
    });

    test('no document contains a real-looking key or secret', () {
      final key = RegExp(r'(gsk_|AIza|sk-[A-Za-z0-9]{20}|-----BEGIN)');
      for (final doc in legalDocuments) {
        expect(key.hasMatch(_read(doc.asset)), isFalse, reason: doc.asset);
      }
    });
  });

  group('viewer', () {
    testWidgets('the hub lists every document', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const LegalHubPage()));
      for (final doc in legalDocuments) {
        expect(find.text(doc.title), findsWidgets, reason: doc.title);
      }
    });

    testWidgets('opening a document shows its text and highlights placeholders',
        (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const LegalHubPage()));
      await tester.tap(find.text('Privacy Policy').first);
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.textContaining('We do not use analytics', findRichText: true),
          findsWidgets);
      expect(find.textContaining('[[CONTROLLER_NAME]]', findRichText: true),
          findsWidgets);
    });

    testWidgets('a missing asset shows a message instead of crashing',
        (tester) async {
      await tester.pumpWidget(_app(const LegalDocumentPage(
        document: LegalDocument(
            id: 'nope', title: 'Missing', summary: '', icon: Icons.error),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
    });
  });
}
