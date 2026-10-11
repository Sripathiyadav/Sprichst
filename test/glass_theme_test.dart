import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/domain/models/learning_models.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// What the eye sees: [glass] (with its alpha) laid over an opaque [backdrop].
Color _over(Color glass, Color backdrop) => Color.alphaBlend(glass, backdrop);

void main() {
  group('GlassTheme tokens', () {
    test('every token moves monotonically with intensity', () {
      final low = GlassTheme.fromProfile(SurfaceStyle.glass, 0);
      final high = GlassTheme.fromProfile(SurfaceStyle.glass, 100);
      expect(high.blurSigma, greaterThan(low.blurSigma));
      expect(high.specular, greaterThan(low.specular));
      expect(high.ambientStrength, greaterThan(low.ambientStrength));
      expect(high.shadow, greaterThan(low.shadow));
      for (final b in Brightness.values) {
        expect(high.tintOpacity(b), lessThan(low.tintOpacity(b)),
            reason: 'more intensity means more see-through (${b.name})');
      }
    });

    test('opacity never drops below the legibility floor', () {
      for (var percent = 0; percent <= 100; percent++) {
        final glass = GlassTheme.fromProfile(SurfaceStyle.glass, percent);
        expect(glass.tintOpacity(Brightness.light),
            greaterThanOrEqualTo(GlassTheme.lightOpacityFloor));
        expect(glass.tintOpacity(Brightness.dark),
            greaterThanOrEqualTo(GlassTheme.darkOpacityFloor));
      }
    });

    test('standard style has no ambient light and ignores intensity', () {
      expect(GlassTheme.standard.enabled, isFalse);
      expect(GlassTheme.standard.ambientStrength, 0);
    });

    test('the percentage is clamped', () {
      expect(GlassTheme.fromProfile(SurfaceStyle.glass, 400).intensity, 1);
      expect(GlassTheme.fromProfile(SurfaceStyle.glass, -5).intensity, 0);
    });
  });

  group('text stays readable on glass at every intensity', () {
    for (final brightness in Brightness.values) {
      test('${brightness.name} mode, over the worst backdrops', () {
        final theme = SprichstTheme.build(brightness);
        final scheme = theme.colorScheme;
        final palette = SprichstPalette.flag;
        final isDark = brightness == Brightness.dark;
        // The brightest and darkest things the app can place behind glass.
        // Pure white never sits behind dark-mode glass (every dark surface is
        // near-black and the brightest element is the gold plan card), and pure
        // black only appears behind light glass as the black plan card.
        final backdrops = <String, Color>{
          'page': theme.scaffoldBackgroundColor,
          if (!isDark) 'white': Colors.white,
          'black': Colors.black,
          'flag red': FlagColors.red,
          'flag gold': FlagColors.gold,
          'ambient red':
              Color(palette.red.get(brightness == Brightness.dark ? 38 : 80)),
          'ambient gold':
              Color(palette.gold.get(brightness == Brightness.dark ? 42 : 86)),
        };

        for (var percent = 0; percent <= 100; percent += 5) {
          final glass = GlassTheme.fromProfile(SurfaceStyle.glass, percent);
          // The top of the surface carries the sheen: the worst case.
          final tops = {
            'card': glass.topFill(scheme),
            'tinted': glass.topFill(scheme, tint: scheme.surfaceContainerHigh),
          };
          for (final top in tops.entries) {
            for (final backdrop in backdrops.entries) {
              final seen = _over(top.value, backdrop.value);
              for (final ink in {
                'onSurface': scheme.onSurface,
                'onSurfaceVariant': scheme.onSurfaceVariant,
              }.entries) {
                expect(_contrast(ink.value, seen), greaterThanOrEqualTo(4.5),
                    reason:
                        '${top.key} ${ink.key} over ${backdrop.key} at $percent%');
              }
            }
          }
        }
      });
    }
  });
}
