import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/repo_files.dart';

/// Guards the promise in legal/privacy-policy.md: nothing about a visitor is
/// sent to a third party until they act, and no analytics, advertising or
/// session-replay tool is present.
///
/// If one of these fails, either remove the dependency or, if it is truly
/// needed, add consent for it and update legal/privacy-policy.md first.
void main() {
  final files = repositoryFiles().where(isText).toList();

  String pubspec() => File('pubspec.yaml').readAsStringSync();
  String lockfile() => File('pubspec.lock').readAsStringSync();

  group('no tracking tools', () {
    // Analytics, advertising, attribution, crash reporting and session replay.
    // Session replay records what a person does on screen, so it is covered
    // by name as well as by the general analytics list.
    const forbiddenPackages = [
      'google_fonts',
      'firebase_analytics',
      'firebase_crashlytics',
      'firebase_performance',
      'firebase_messaging',
      'firebase_remote_config',
      'firebase_app_check', // not tracking, but would load extra Google scripts
      'google_mobile_ads',
      'sentry',
      'sentry_flutter',
      'posthog_flutter',
      'mixpanel_flutter',
      'amplitude_flutter',
      'segment_analytics',
      'datadog_flutter_plugin',
      'datadog_session_replay',
      'smartlook',
      'clarity_flutter',
      'fullstory_flutter',
      'logrocket_flutter',
      'uxcam',
      'hotjar_flutter',
      'appsflyer_sdk',
      'adjust_sdk',
      'facebook_app_events',
      'flutter_facebook_auth',
      'onesignal_flutter',
      'bugsnag_flutter',
      'instabug_flutter',
      'countly_flutter',
      'matomo_tracker',
    ];

    test('pubspec.yaml and pubspec.lock list none of them', () {
      final declared = RegExp(r'^\s{2}([a-z0-9_]+):', multiLine: true);
      final names = {
        for (final text in [pubspec(), lockfile()])
          for (final m in declared.allMatches(text)) m.group(1)!,
      };
      expect(names.intersection(forbiddenPackages.toSet()), isEmpty,
          reason: 'A tracking or session-replay package was added.');
    });

    test('no analytics or replay SDK is initialised in code or web files', () {
      final markers = RegExp(
        r'googletagmanager|google-analytics|gtag\(|analytics\.js|'
        r'hotjar|clarity\.ms|fullstory|logrocket|smartlook|mouseflow|'
        r'posthog|mixpanel|amplitude\.com|segment\.(com|io)|sentry\.io|'
        r'datadoghq|crashlytics|uxcam|connect\.facebook\.net|'
        r'doubleclick|adservice\.google',
        caseSensitive: false,
      );
      final hits = <String>[];
      for (final file in files) {
        final path = file.path;
        final scanned = path.startsWith('lib/') ||
            path.startsWith('web/') && !path.startsWith('web/vendor/') ||
            path == 'pubspec.yaml' ||
            path.startsWith('android/app/src/main') ||
            path.startsWith('ios/Runner');
        if (!scanned) continue;
        if (markers.hasMatch(readText(file))) hits.add(path);
      }
      expect(hits, isEmpty);
    });
  });

  group('no visitor data goes to Google when a page opens', () {
    final index = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    test('web/index.html loads nothing from another origin', () {
      final external = RegExp(r'''(src|href)\s*=\s*["']https?://''');
      expect(external.hasMatch(index), isFalse,
          reason: 'External scripts, fonts or styles are loaded.');
      expect(index, isNot(contains('google-signin-client_id')),
          reason: 'That meta tag makes the Google Identity script load at '
              'start-up. Web sign-in uses the Firebase popup instead.');
      expect(index, contains('no-referrer'));
    });

    test('Flutter is told to use local CanvasKit and no font CDN', () {
      expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
      expect(bootstrap, contains('fontFallbackBaseUrl'));
      expect(bootstrap, isNot(contains('http')),
          reason: 'The bootstrap must not name an external host.');
    });

    test('Roboto is bundled, so Flutter does not fetch it from Google', () {
      expect(pubspec(), contains('family: Roboto'));
      for (final weight in ['Light', 'Regular', 'Medium', 'Bold', 'Black']) {
        expect(
            File('assets/fonts/roboto/Roboto-$weight.ttf').existsSync(), isTrue,
            reason: 'Roboto-$weight.ttf is missing.');
      }
      expect(File('assets/fonts/roboto/LICENSE.txt').existsSync(), isTrue);
    });

    test(
        'the Firebase JavaScript SDK is served from web/vendor, at the '
        'version FlutterFire expects', () {
      final package =
          Process.runSync('python3', ['scripts/vendor_web_deps.py', '--check'])
              .stdout
              .toString();
      expect(package, contains('is vendored'),
          reason: 'Run: python3 scripts/vendor_web_deps.py\n$package');
      expect(bootstrap, contains('vendor/firebasejs/'));
      for (final name in [
        'firebase-app.js',
        'firebase-auth.js',
        'firebase-firestore-pipelines.js',
      ]) {
        final code = File('web/vendor/firebasejs/$name').readAsStringSync();
        expect(code, isNot(contains('gstatic.com/firebasejs')),
            reason: '$name still imports from Google\'s CDN.');
      }
    });

    test('google_sign_in_web is replaced by the do-nothing stub', () {
      expect(pubspec(), contains('dependency_overrides:'));
      expect(pubspec(), contains('path: tool/stubs/google_sign_in_web'));
      final stub =
          File('tool/stubs/google_sign_in_web/lib/google_sign_in_web.dart')
              .readAsStringSync();
      expect(stub, isNot(contains('loadWebSdk')));
    });
  });

  group('network destinations are known', () {
    // Hosts the app may contact from its own code. Anything else needs a line
    // in legal/privacy-policy.md and in legal/internal/data-inventory.md.
    const allowedHosts = {
      'huggingface.co', // on-device model downloads the learner asks for
      'github.com', // on-device speech model downloads the learner asks for
      // The AI accounts the learner can bring their own key for; the app calls
      // one of them only when the learner has saved a key for it.
      'api.groq.com', 'generativelanguage.googleapis.com', 'api.openai.com',
      'api.anthropic.com', 'api.x.ai', 'api.mistral.ai', 'api.deepseek.com',
      'openrouter.ai',
      '127.0.0.1', 'localhost', '10.0.2.2', '192.168.1.20', // development
      'developer.android.com', // comments
    };

    test('code only names hosts that are documented', () {
      final url = RegExp(r'https?://([A-Za-z0-9.-]+)');
      final unknown = <String>{};
      for (final file in files.where((f) => f.path.startsWith('lib/'))) {
        for (final m in url.allMatches(readText(file))) {
          if (!allowedHosts.contains(m.group(1))) {
            unknown.add('${m.group(1)} in ${file.path}');
          }
        }
      }
      expect(unknown, isEmpty);
    });
  });
}
