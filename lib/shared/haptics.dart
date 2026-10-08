import 'package:flutter/services.dart';

/// Light, purposeful feedback, as on Apple platforms: a tick for selection, a
/// soft tap for success, a firmer one for a mistake. Silent where unsupported.
abstract final class Haptics {
  static void selection() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.lightImpact();
  static void mistake() => HapticFeedback.mediumImpact();
}
