import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/color_system.dart';

/// Perceptual lightness (CIE L*) from 0 to 100.
double _lightness(Color c) {
  final y = c.computeLuminance();
  return y <= 216 / 24389 ? y * 24389 / 27 : 116 * math.pow(y, 1 / 3) - 16;
}

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
  for (final tokens in [SprichstTokens.light, SprichstTokens.dark]) {
    final name = tokens.brightness.name;
    final scheme = tokens.scheme;

    group('$name scheme', () {
      test('fills the Material roles from the tokens, as the design maps them',
          () {
        expect(scheme.surface, tokens.surface);
        expect(scheme.surfaceContainerLow, tokens.canvas);
        expect(scheme.surfaceContainerHighest, tokens.surfaceSunken);
        expect(scheme.onSurface, tokens.ink);
        expect(scheme.onSurfaceVariant, tokens.inkMuted);
        expect(scheme.outline, tokens.lineStrong);
        expect(scheme.outlineVariant, tokens.line);
        expect(scheme.primary, tokens.action);
        expect(scheme.onPrimary, tokens.onAction);
        expect(scheme.secondary, tokens.accent);
        expect(scheme.secondaryContainer, tokens.accentSoft);
        expect(scheme.tertiary, tokens.success);
        expect(scheme.tertiaryContainer, tokens.successSoft);
        expect(scheme.error, tokens.danger);
        expect(scheme.errorContainer, tokens.dangerSoft);
        expect(scheme.inverseSurface, tokens.panel);
        expect(scheme.onInverseSurface, tokens.onPanel);
      });

      test('surfaces step in lightness from sunken to surface', () {
        final lightMode = tokens.brightness == Brightness.light;
        final steps = [tokens.surfaceSunken, tokens.canvas, tokens.surface]
            .map(_lightness)
            .toList();
        if (lightMode) {
          expect(steps[0], lessThan(steps[1]));
          expect(steps[1], lessThan(steps[2]));
        } else {
          // Dark: the sunken well is the darkest, the surface the lightest.
          expect(steps[0], lessThan(steps[1]));
          expect(steps[1], lessThan(steps[2]));
        }
      });

      test('the canvas is never pure black or pure white', () {
        expect(tokens.canvas, isNot(const Color(0xFF000000)));
        expect(tokens.canvas, isNot(const Color(0xFFFFFFFF)));
      });
    });

    group('$name colour-blind safety', () {
      for (final entry in _simulations.entries) {
        test('success and danger text stay apart under ${entry.key}', () {
          // Teal success and crimson danger sit off the red-green axis. Dark
          // protanopia is the closest pair (about 9 CIE76 units); the design
          // system never relies on it: every status pairs an icon and a word
          // (see option_tile_test).
          final success = _simulate(tokens.success, entry.value);
          final danger = _simulate(tokens.danger, entry.value);
          expect(_deltaE(success, danger), greaterThan(8),
              reason: 'success ${tokens.success} vs danger ${tokens.danger}');
        });
      }
    });
  }
}

/// CIE76 colour difference between two sRGB colours.
double _deltaE(Color a, Color b) {
  List<double> lab(Color c) {
    final r = _linear(c.r), g = _linear(c.g), bl = _linear(c.b);
    final x = .4124 * r + .3576 * g + .1805 * bl;
    final y = .2126 * r + .7152 * g + .0722 * bl;
    final z = .0193 * r + .1192 * g + .9505 * bl;
    double f(double t) => t > 216 / 24389
        ? math.pow(t, 1 / 3).toDouble()
        : (24389 / 27 * t + 16) / 116;
    final fx = f(x / .95047), fy = f(y), fz = f(z / 1.08883);
    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  final p = lab(a), q = lab(b);
  return math.sqrt(math.pow(p[0] - q[0], 2) +
      math.pow(p[1] - q[1], 2) +
      math.pow(p[2] - q[2], 2));
}
