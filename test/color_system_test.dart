import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:sprichst/app/theme/color_system.dart';

final _palette = SprichstPalette.flag;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

double _lightness(Color c) => Hct.fromInt(c.toARGB32()).tone;

/// Linear-RGB colour-vision-deficiency simulation (Machado et al., 2009,
/// severity 1.0). Each matrix maps linear RGB to what that viewer sees.
const _simulations = <String, List<double>>{
  'protanopia': [
    .152286, 1.052583, -.204868, //
    .114503, .786281, .099216,
    -.003882, -.048116, 1.051998,
  ],
  'deuteranopia': [
    .367322, .860646, -.227968, //
    .280085, .672501, .047413,
    -.011820, .042940, .968881,
  ],
  'tritanopia': [
    1.255528, -.076749, -.178779, //
    -.078411, .930809, .147602,
    .004733, .691367, .303900,
  ],
};

double _linear(double c) =>
    c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();

double _gamma(double c) {
  final v = c.clamp(0.0, 1.0);
  return v <= .0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - .055;
}

Color _simulate(Color color, List<double> m) {
  final r = _linear(color.r), g = _linear(color.g), b = _linear(color.b);
  return Color.from(
    alpha: 1,
    red: _gamma(m[0] * r + m[1] * g + m[2] * b),
    green: _gamma(m[3] * r + m[4] * g + m[5] * b),
    blue: _gamma(m[6] * r + m[7] * g + m[8] * b),
  );
}

void main() {
  group('toneOn derives foregrounds that meet the requested contrast', () {
    test('for every background tone and every target ratio', () {
      for (var background = 0; background <= 100; background++) {
        for (final ratio in [3.0, 4.5, 7.0, 12.0]) {
          final tone = SprichstPalette.toneOn(background.toDouble(), ratio);
          final fg = Color(_palette.neutral.get(tone));
          final bg = Color(_palette.neutral.get(background));
          // Mid-tone backgrounds cannot reach 12:1 in either direction; for
          // every other case the derived tone must meet the ratio.
          final reachable =
              Contrast.ratioOfTones(0, background.toDouble()) >= ratio ||
                  Contrast.ratioOfTones(100, background.toDouble()) >= ratio;
          if (reachable) {
            expect(_contrast(fg, bg), greaterThanOrEqualTo(ratio - .05),
                reason: 'bg tone $background, ratio $ratio, got tone $tone');
          }
        }
      }
    });

    test('keeps the preferred tone when it already works', () {
      expect(SprichstPalette.toneOn(100, 4.5, preferred: 20), 20);
      // A preferred tone that fails is replaced by the nearest one that passes.
      final fixed = SprichstPalette.toneOn(100, 4.5, preferred: 80);
      expect(fixed, lessThan(80));
      expect(Contrast.ratioOfTones(fixed.toDouble(), 100),
          greaterThanOrEqualTo(4.5));
    });
  });

  group('brand fidelity', () {
    test('the seed hues are the flag’s red and gold', () {
      expect(SprichstPalette.redHue, closeTo(27.4, 1));
      expect(SprichstPalette.goldHue, closeTo(92.7, 1));
    });

    test('brand colours appear exactly where their contrast allows', () {
      final light = _palette.scheme(Brightness.light);
      final dark = _palette.scheme(Brightness.dark);
      expect(light.secondary, FlagColors.red,
          reason: 'flag red on white reads');
      expect(light.tertiary, FlagColors.gold);
      expect(dark.primary, FlagColors.gold, reason: 'flag gold glows on black');
      expect(_palette.background(Brightness.dark), FlagColors.black);
    });
  });

  group('harmony', () {
    test('red and gold are analogous: a narrow warm arc, under 90° apart', () {
      final span = (SprichstPalette.goldHue - SprichstPalette.redHue).abs();
      expect(span, lessThan(90));
    });

    test('neutrals are barely chromatic and share the gold hue', () {
      for (final tone in [10, 50, 90, 97]) {
        final hct = Hct.fromInt(_palette.neutral.get(tone));
        expect(hct.chroma, lessThan(8), reason: 'neutral tone $tone');
      }
      final warm = Hct.fromInt(_palette.neutral.get(90));
      expect((warm.hue - SprichstPalette.goldHue).abs(), lessThan(15));
    });

    test('surfaces step in lightness, from page to raised, in both modes', () {
      for (final brightness in Brightness.values) {
        final s = _palette.scheme(brightness);
        final tones = [
          s.surfaceContainerLowest,
          s.surfaceContainerLow,
          s.surfaceContainer,
          s.surfaceContainerHigh,
          s.surfaceContainerHighest,
        ].map(_lightness).toList();
        final ordered =
            brightness == Brightness.light ? tones.reversed.toList() : tones;
        expect([...ordered]..sort(), ordered,
            reason: '${brightness.name} steps');
      }
    });
  });

  group('colour-blind safety', () {
    for (final entry in _simulations.entries) {
      test('success and error stay distinguishable under ${entry.key}', () {
        for (final brightness in Brightness.values) {
          final s = _palette.scheme(brightness);
          Color seen(Color c) => _simulate(c, entry.value);

          // Emphasis colours (borders, icons, accents) differ strongly in
          // lightness, so they survive losing red-green discrimination.
          expect(
            (_lightness(seen(s.tertiary)) - _lightness(seen(s.error))).abs(),
            greaterThan(20),
            reason: '${brightness.name}: gold vs red emphasis',
          );
          // Their container fills must still differ measurably.
          expect(
            (_lightness(seen(s.tertiaryContainer)) -
                    _lightness(seen(s.errorContainer)))
                .abs(),
            greaterThan(4),
            reason: '${brightness.name}: success vs error fill',
          );
        }
      });
    }
  });
}
