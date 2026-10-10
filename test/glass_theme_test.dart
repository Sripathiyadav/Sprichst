import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/domain/models/learning_models.dart';

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
}
