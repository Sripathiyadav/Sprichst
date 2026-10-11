import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// Holds the design system's pairs to WCAG AA in both themes. Each pair is the
/// one a token's usage note names: ink on canvas, surface and every soft tint,
/// muted ink on its three grounds, panel text on the panel, and so on.
void main() {
  for (final entry in {
    'light': SprichstTokens.light,
    'dark': SprichstTokens.dark,
  }.entries) {
    group('${entry.key} tokens', () {
      final t = entry.value;

      test('text reaches 4.5:1 on the grounds it is used on', () {
        final pairs = <String, (Color, Color)>{
          'ink on canvas': (t.ink, t.canvas),
          'ink on surface': (t.ink, t.surface),
          'ink on surface-sunken': (t.ink, t.surfaceSunken),
          'ink on accent-soft': (t.ink, t.accentSoft),
          'ink on success-soft': (t.ink, t.successSoft),
          'ink on warning-soft': (t.ink, t.warningSoft),
          'ink on danger-soft': (t.ink, t.dangerSoft),
          'ink-muted on canvas': (t.inkMuted, t.canvas),
          'ink-muted on surface': (t.inkMuted, t.surface),
          'ink-muted on surface-sunken': (t.inkMuted, t.surfaceSunken),
          'on-panel on panel': (t.onPanel, t.panel),
          'on-panel-muted on panel': (t.onPanelMuted, t.panel),
          'accent-on-panel on panel': (t.accentOnPanel, t.panel),
          'on-action on action': (t.onAction, t.action),
          'on-accent on accent': (t.onAccent, t.accent),
          'accent on canvas': (t.accent, t.canvas),
          'accent on surface': (t.accent, t.surface),
          'accent on surface-sunken': (t.accent, t.surfaceSunken),
          'accent on accent-soft': (t.accent, t.accentSoft),
          'success on canvas': (t.success, t.canvas),
          'success on surface': (t.success, t.surface),
          'success on success-soft': (t.success, t.successSoft),
          'warning on canvas': (t.warning, t.canvas),
          'warning on surface': (t.warning, t.surface),
          'warning on warning-soft': (t.warning, t.warningSoft),
          'danger on canvas': (t.danger, t.canvas),
          'danger on surface': (t.danger, t.surface),
          'danger on danger-soft': (t.danger, t.dangerSoft),
          'der chip': (t.articleDerInk, t.articleDerBg),
          'die chip': (t.articleDieInk, t.articleDieBg),
          'das chip': (t.articleDasInk, t.articleDasBg),
        };
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
        }
      });

      test('controls, marks and large coral reach 3:1', () {
        final pairs = <String, (Color, Color)>{
          'control border on canvas': (t.lineStrong, t.canvas),
          'control border on surface': (t.lineStrong, t.surface),
          'chart mark on surface': (t.mark, t.surface),
          'chart mark on canvas': (t.mark, t.canvas),
          'coral (24px and up) on canvas': (t.coral, t.canvas),
          'coral (24px and up) on surface': (t.coral, t.surface),
          'action arrow on action': (t.actionGlyph, t.action),
          'focus ring on canvas': (t.ink, t.canvas),
          'focus ring on surface': (t.ink, t.surface),
          'focus ring on panel': (t.onPanel, t.panel),
        };
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(3), reason: name);
        }
      });

      test('the theme paints its text from these tokens', () {
        final theme = SprichstTheme.build(t.brightness);
        expect(theme.scaffoldBackgroundColor, t.canvas);
        expect(theme.colorScheme.surface, t.surface);
        expect(theme.colorScheme.primary, t.action);
        expect(theme.textTheme.bodyLarge!.color, t.ink);
        expect(theme.textTheme.bodySmall!.color, t.inkMuted);
        expect(theme.extension<SprichstTokens>(), isNotNull);
      });
    });
  }

  test('the strongest control is the highest-contrast one in both themes', () {
    // Charcoal in light, coral in dark: each is the primary action's fill.
    expect(SprichstTokens.light.action, const Color(0xFF2A2826));
    expect(SprichstTokens.dark.action, SprichstTokens.dark.accent);
  });
}
