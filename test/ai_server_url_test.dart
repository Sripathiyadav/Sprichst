import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/ai_server_url.dart';

void main() {
  test('the Android emulator reaches the computer through 10.0.2.2', () {
    expect(
      aiServerUrl(
          configured: '', isWeb: false, platform: TargetPlatform.android),
      'http://10.0.2.2:8000',
    );
  });

  test('the iOS simulator, desktop and web use the loopback address', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      expect(
        aiServerUrl(configured: '', isWeb: false, platform: platform),
        'http://127.0.0.1:8000',
      );
    }
    expect(
      aiServerUrl(
          configured: '', isWeb: true, platform: TargetPlatform.android),
      'http://127.0.0.1:8000',
    );
  });

  test('a configured URL wins, without a trailing slash', () {
    expect(
      aiServerUrl(
        configured: 'http://192.168.1.20:8000/',
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      'http://192.168.1.20:8000',
    );
  });
}
