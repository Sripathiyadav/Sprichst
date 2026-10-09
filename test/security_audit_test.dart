import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/repo_files.dart';

/// Guards the promises in SECURITY.md: no secrets in what is committed, and no
/// raw SQL or database drivers (the app talks to Firestore through its SDK, and
/// the AI server has no database).
void main() {
  final files = repositoryFiles().where(isText).toList();

  group('no secrets in the repository', () {
    final patterns = <String, RegExp>{
      'Google API key': RegExp(r'AIza[0-9A-Za-z_\-]{35}'),
      'Groq API key': RegExp(r'gsk_[A-Za-z0-9]{20,}'),
      'OpenAI/Anthropic style key': RegExp(r'\bsk-(ant-)?[A-Za-z0-9_\-]{20,}'),
      'AWS access key': RegExp(r'AKIA[0-9A-Z]{16}'),
      'GitHub token': RegExp(r'gh[pousr]_[A-Za-z0-9]{36,}'),
      'Slack token': RegExp(r'xox[baprs]-[A-Za-z0-9-]{10,}'),
      'private key':
          RegExp(r'-----BEGIN (RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----'),
      'hard-coded credential': RegExp(
        r'''(api[_-]?key|secret|token|passw(or)?d)\s*[:=]\s*["'][A-Za-z0-9_\-/+=]{20,}["']''',
        caseSensitive: false,
      ),
    };

    // Vendored third-party code and generated files are not ours to scan.
    bool skipped(String path) =>
        path.startsWith('web/vendor/') ||
        path == 'pubspec.lock' ||
        path.endsWith('package-lock.json') ||
        path.startsWith('firebase/node_modules/') ||
        path.startsWith('test/security_audit_test.dart');

    test('no committed file contains a key, token or private key', () {
      final hits = <String>[];
      for (final file in files) {
        if (skipped(file.path)) continue;
        final text = readText(file);
        for (final entry in patterns.entries) {
          if (entry.value.hasMatch(text)) {
            hits.add('${entry.key}: ${file.path}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'Remove the secret, rotate it, and load it from the '
              'environment instead (see SECURITY.md).');
    });

    test('files that hold local secrets are git-ignored', () {
      final ignore = File('.gitignore').readAsStringSync();
      for (final entry in [
        'ai-server/.env',
        'lib/firebase_options.dart',
        'android/app/google-services.json',
        'ios/Runner/GoogleService-Info.plist',
      ]) {
        expect(ignore, contains(entry), reason: '$entry must be ignored.');
      }
    });

    test('the AI provider key is read on the server only', () {
      final dart = files.where((f) => f.path.startsWith('lib/'));
      for (final file in dart) {
        expect(readText(file), isNot(contains('GROQ_API_KEY')),
            reason: '${file.path} mentions the server-side provider key.');
      }
      expect(File('ai-server/.env.example').readAsStringSync(),
          isNot(matches(RegExp(r'GROQ_API_KEY=\S'))),
          reason: 'The example file must not contain a real key.');
    });

    test('the web bundle contains no provider key', () {
      final bundle = File('build/web/main.dart.js');
      if (!bundle.existsSync()) {
        markTestSkipped('Run `flutter build web` first to scan the bundle.');
        return;
      }
      final text = bundle.readAsStringSync();
      expect(text, isNot(contains('GROQ')));
      expect(RegExp(r'gsk_[A-Za-z0-9]{20,}').hasMatch(text), isFalse);
    });
  });

  group('no raw SQL', () {
    // The gateway has no database, and the app uses Firestore through its SDK.
    // If a SQL database is ever added, use parameterised statements only, then
    // update this test and SECURITY.md.
    const databasePackages = [
      'sqflite',
      'sqflite_common',
      'sqlite3',
      'drift',
      'floor',
      'postgres',
      'mysql1',
      'mysql_client',
      'supabase',
      'supabase_flutter',
      'isar',
      'objectbox',
    ];

    test('no SQL driver or ORM is a dependency', () {
      final declared = RegExp(r'^\s{2}([a-z0-9_]+):', multiLine: true);
      final names = {
        for (final text in [
          File('pubspec.yaml').readAsStringSync(),
          File('pubspec.lock').readAsStringSync(),
        ])
          for (final m in declared.allMatches(text)) m.group(1)!,
      };
      expect(names.intersection(databasePackages.toSet()), isEmpty);
    });

    test('no source file builds a SQL statement', () {
      final sql = RegExp(
        r'\b(select\b[^;\n]{1,80}\bfrom\b|insert\s+into|update\s+\w+\s+set|'
        r'delete\s+from|drop\s+table|create\s+table|alter\s+table)\b',
        caseSensitive: false,
      );
      final hits = <String>[];
      for (final file in files) {
        final path = file.path;
        final code = (path.startsWith('lib/') && path.endsWith('.dart')) ||
            (path.startsWith('ai-server/app/') && path.endsWith('.py')) ||
            path.startsWith('tool/');
        if (!code) continue;
        if (sql.hasMatch(readText(file))) hits.add(path);
      }
      expect(hits, isEmpty);
    });
  });
}
