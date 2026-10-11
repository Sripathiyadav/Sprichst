import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/models/learning_models.dart';

/// The learner's Liquid Glass choice, turned into concrete drawing values.
///
/// [intensity] runs from 0 (almost opaque, calm) to 1 (most see-through, most
/// light). One number drives every token, so the setting feels like a single
/// dial. Legibility is protected by [tintOpacity]'s floor: however high the
/// intensity, glass stays opaque enough for text to read against any backdrop
/// the app can put behind it (a test checks this against black, white, flag red
/// and flag gold).
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  const GlassTheme({required this.style, required this.intensity})
      : assert(intensity >= 0 && intensity <= 1);

  factory GlassTheme.fromProfile(SurfaceStyle style, int percent) =>
      GlassTheme(style: style, intensity: percent.clamp(0, 100) / 100);

  /// Flat, opaque surfaces: no glass anywhere.
  static const standard =
      GlassTheme(style: SurfaceStyle.standard, intensity: 0);

  final SurfaceStyle style;
  final double intensity;

  bool get enabled => style == SurfaceStyle.glass;

  /// How much of [specular] the top sheen uses. Dark glass is kept gentle: a
  /// white wash lightens it, which would cost contrast against light text.
  static const sheenLight = .35;
  static const sheenDark = .08;

  /// Lowest fill opacity, per brightness, that keeps text at 4.5:1 over the
  /// worst backdrop. Dark glass needs more fill because bright accents (gold)
  /// behind it would otherwise wash out light text.
  static const lightOpacityFloor = .68;
  static const darkOpacityFloor = .86;
  static const _maxOpacity = .94;

  /// How strongly the backdrop is blurred (floating navigation only).
  double get blurSigma => lerpDouble(10, 34, intensity)!;

  /// Fill opacity. Lower means more see-through; never below the floor.
  double tintOpacity(Brightness brightness) {
    final floor =
        brightness == Brightness.light ? lightOpacityFloor : darkOpacityFloor;
    return lerpDouble(_maxOpacity, floor, intensity)!;
  }

  /// Strength of the soft red/gold light behind the glass, which gives the
  /// glass something to refract. Zero in standard mode.
  double get ambientStrength => enabled ? lerpDouble(.30, .85, intensity)! : 0;

  /// Brightness of the light-catching edge and top sheen.
  double get specular => lerpDouble(.25, .85, intensity)!;

  /// Depth of the floating shadow.
  double get shadow => lerpDouble(.06, .16, intensity)!;

  /// The glass fill for a surface: the base colour at [tintOpacity].
  Color fill(ColorScheme scheme, {Color? tint}) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = tint ?? (isDark ? scheme.surfaceContainer : scheme.surface);
    return base.withValues(alpha: tintOpacity(scheme.brightness));
  }

  /// The fill at the very top, where the specular sheen is strongest. This is
  /// the lightest (in dark mode) or brightest part, so it is the worst case for
  /// text legibility and what the tests measure.
  Color topFill(ColorScheme scheme, {Color? tint}) {
    final isDark = scheme.brightness == Brightness.dark;
    final sheen = Colors.white.withValues(
      alpha: specular * (isDark ? sheenDark : sheenLight),
    );
    return Color.alphaBlend(sheen, fill(scheme, tint: tint));
  }

  /// The same theme with glass off, used when the system asks for less
  /// transparency (High Contrast).
  GlassTheme get opaque => standard;

  @override
  GlassTheme copyWith({SurfaceStyle? style, double? intensity}) => GlassTheme(
        style: style ?? this.style,
        intensity: intensity ?? this.intensity,
      );

  @override
  GlassTheme lerp(GlassTheme? other, double t) {
    if (other == null) return this;
    return GlassTheme(
      style: t < .5 ? style : other.style,
      intensity: lerpDouble(intensity, other.intensity, t)!,
    );
  }
}

extension GlassContext on BuildContext {
  /// The glass settings in effect here. High Contrast (iOS "Increase Contrast",
  /// Android high-contrast text) is treated as "reduce transparency".
  GlassTheme get glass {
    final theme = Theme.of(this).extension<GlassTheme>() ?? GlassTheme.standard;
    return MediaQuery.highContrastOf(this) ? theme.opaque : theme;
  }
}
