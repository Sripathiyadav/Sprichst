import 'package:flutter/foundation.dart';

/// Set with `--dart-define=AI_SERVER_URL=http://192.168.1.20:8000` to reach
/// the gateway from a real phone (or a deployed HTTPS gateway).
const _configuredUrl = String.fromEnvironment('AI_SERVER_URL');

/// Where the AI gateway runs during development.
///
/// The iOS simulator, desktop and web share the computer's network, so
/// 127.0.0.1 reaches the gateway. The Android emulator has its own loopback;
/// 10.0.2.2 is its alias for the computer running it.
String aiServerUrl({
  String configured = _configuredUrl,
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  if (configured.isNotEmpty) {
    return configured.endsWith('/')
        ? configured.substring(0, configured.length - 1)
        : configured;
  }
  if (!isWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}
