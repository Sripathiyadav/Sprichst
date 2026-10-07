import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

void main() {
  const minimum = 4.5; // WCAG AA for body text.

  for (final entry in {
    'light': SprichstTheme.light,
    'dark': SprichstTheme.dark,
  }.entries) {
    test('${entry.key} theme text is readable on the surfaces it appears on',
        () {
      final theme = entry.value;
      final scheme = theme.colorScheme;
      final body = theme.textTheme.bodyMedium!.color!;
      final strong = theme.textTheme.bodyLarge!.color!;

      final pairs = <String, (Color, Color)>{
        'body on scaffold': (body, theme.scaffoldBackgroundColor),
        'strong on scaffold': (strong, theme.scaffoldBackgroundColor),
        'body on card': (body, scheme.surface),
        'strong on card': (strong, scheme.surface),
        // Feedback and highlight cards use default text on these fills.
        'body on success surface': (body, scheme.primaryContainer),
        'strong on success surface': (strong, scheme.primaryContainer),
        'body on soft surface': (body, scheme.secondaryContainer),
        'strong on soft surface': (strong, scheme.secondaryContainer),
        'body on danger surface': (body, scheme.errorContainer),
        'on primary': (scheme.onPrimary, scheme.primary),
        'primary on card': (scheme.primary, scheme.surface),
        'primary on scaffold': (scheme.primary, theme.scaffoldBackgroundColor),
        'error on card': (scheme.error, scheme.surface),
        'on error': (scheme.onError, scheme.error),
      };

      for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(minimum), reason: name);
      }
    });
  }
}
