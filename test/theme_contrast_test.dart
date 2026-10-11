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
  test('the brand colours are the official flag values', () {
    expect(FlagColors.black, const Color(0xFF000000));
    expect(FlagColors.red, const Color(0xFFDD0000));
    expect(FlagColors.gold, const Color(0xFFFFCE00));
  });

  for (final entry in {
    'light': SprichstTheme.light,
    'dark': SprichstTheme.dark,
  }.entries) {
    group('${entry.key} theme', () {
      final theme = entry.value;
      final scheme = theme.colorScheme;
      final body = theme.textTheme.bodyMedium!.color!;
      final strong = theme.textTheme.bodyLarge!.color!;
      final isDark = scheme.brightness == Brightness.dark;
      final accent = isDark ? scheme.primary : scheme.secondary;

      test('text is readable (WCAG AA, 4.5:1) on every surface it appears on',
          () {
        final pairs = <String, (Color, Color)>{
          'body on scaffold': (body, theme.scaffoldBackgroundColor),
          'strong on scaffold': (strong, theme.scaffoldBackgroundColor),
          'body on card': (body, scheme.surface),
          'strong on card': (strong, scheme.surface),
          'body on soft surface': (body, scheme.surfaceContainerHigh),
          'strong on soft surface': (strong, scheme.surfaceContainerHigh),
          'on primary (buttons, plan card)': (scheme.onPrimary, scheme.primary),
          'primary on onPrimary (inverse button)': (
            scheme.primary,
            scheme.onPrimary
          ),
          'on secondary': (scheme.onSecondary, scheme.secondary),
          'on tertiary (gold)': (scheme.onTertiary, scheme.tertiary),
          'correct feedback': (
            scheme.onTertiaryContainer,
            scheme.tertiaryContainer
          ),
          'wrong feedback': (scheme.onErrorContainer, scheme.errorContainer),
          'selected option': (strong, scheme.primaryContainer),
          'on error': (scheme.onError, scheme.error),
          'error text on card': (scheme.error, scheme.surface),
          'error text on scaffold': (
            scheme.error,
            theme.scaffoldBackgroundColor
          ),
          'accent text on card': (accent, scheme.surface),
          'accent text on scaffold': (accent, theme.scaffoldBackgroundColor),
          'snack bar': (scheme.onInverseSurface, scheme.inverseSurface),
        };
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
        }
      });

      test('controls and indicators reach 3:1 against their background', () {
        final pairs = <String, (Color, Color)>{
          'input border on card': (scheme.outline, scheme.surface),
          'option border on card': (scheme.outline, scheme.surface),
          'progress fill on track': (accent, scheme.surfaceContainerHighest),
          'progress fill on card': (accent, scheme.surface),
          'focused border on card': (scheme.onSurface, scheme.surface),
        };
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(3), reason: name);
        }
      });
    });
  }
}
