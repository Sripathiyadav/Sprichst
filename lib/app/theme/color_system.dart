import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// The three colours of the German flag, exactly as published.
abstract final class FlagColors {
  static const black = Color(0xFF000000);
  static const red = Color(0xFFDD0000);
  static const gold = Color(0xFFFFCE00);
}

/// Sprichst's colour system, built from colour theory rather than picked by eye.
///
/// **Colour space.** Everything is expressed in HCT (hue, chroma, tone). Tone is
/// perceptual lightness, so the contrast between two colours follows from their
/// tones and can be *calculated*. Foregrounds are therefore derived from their
/// background ([toneOn]) instead of being hand-tuned and re-checked.
///
/// **Harmony.** The flag gives two analogous warm hues, red (≈27°) and gold
/// (≈93°), anchored by black. Neutrals are tinted with the gold hue at very low
/// chroma, so greys and whites feel warm and belong to the brand instead of
/// reading as cold, unrelated grey.
///
/// **60-30-10.** About 60% of any screen is neutral surface, 30% is ink and
/// neutral containers (black on white, white on black), and the remaining 10% is
/// accent: red on light surfaces, gold on dark ones. Accent therefore stays
/// meaningful: it marks the primary action, progress, and state.
///
/// **Light and dark are mirrors in tone.** Light mode puts dark ink on near-white
/// tones; dark mode puts light ink on near-black tones. Chromatic roles keep
/// their hue and change tone, so the brand reads the same in both.
class SprichstPalette {
  SprichstPalette._()
      : neutral = TonalPalette.of(_gold.hue, 4),
        neutralVariant = TonalPalette.of(_gold.hue, 8),
        red = TonalPalette.of(_red.hue, _red.chroma),
        gold = TonalPalette.of(_gold.hue, _gold.chroma);

  /// The one shared instance; palettes are immutable.
  static final SprichstPalette flag = SprichstPalette._();

  static final _red = Hct.fromInt(FlagColors.red.toARGB32());
  static final _gold = Hct.fromInt(FlagColors.gold.toARGB32());

  /// Hue of the flag's red and gold, in degrees. Exposed for tests and docs.
  static double get redHue => _red.hue;
  static double get goldHue => _gold.hue;

  final TonalPalette neutral;
  final TonalPalette neutralVariant;
  final TonalPalette red;
  final TonalPalette gold;

  /// Contrast targets (WCAG): body text, large text and UI components, and
  /// enhanced contrast for the primary ink.
  static const textRatio = 4.5;
  static const uiRatio = 3.0;
  static const inkRatio = 12.0;

  /// The tone for a foreground on a [backgroundTone] that reaches [ratio]. It
  /// uses [preferred] when that already works and otherwise moves away from the
  /// background by the least amount, so a derived colour stays as close as
  /// possible to the designer's intent.
  static int toneOn(double backgroundTone, double ratio, {double? preferred}) {
    if (preferred != null &&
        Contrast.ratioOfTones(preferred, backgroundTone) >= ratio) {
      return preferred.round();
    }
    // Prefer the direction with more room: dark ink on light, light on dark.
    final darkFirst = backgroundTone > 50;
    final first = darkFirst
        ? Contrast.darker(tone: backgroundTone, ratio: ratio)
        : Contrast.lighter(tone: backgroundTone, ratio: ratio);
    if (first >= 0) return darkFirst ? first.floor() : first.ceil();
    final second = darkFirst
        ? Contrast.lighter(tone: backgroundTone, ratio: ratio)
        : Contrast.darker(tone: backgroundTone, ratio: ratio);
    if (second >= 0) return darkFirst ? second.ceil() : second.floor();
    return darkFirst ? 0 : 100;
  }

  ColorScheme scheme(Brightness brightness) =>
      brightness == Brightness.light ? _light() : _dark();

  /// The page background behind cards.
  Color background(Brightness brightness) => brightness == Brightness.light
      ? Color(neutral.get(97))
      : FlagColors.black;

  Color _t(TonalPalette palette, int tone) => Color(palette.get(tone));

  ColorScheme _light() {
    // Surfaces: warm white for cards, stepping down for raised containers.
    const surface = 100.0;
    const raised = 90.0; // the darkest surface text is ever placed on

    // Ink: the strongest foreground, derived against the page and card tones.
    final ink = toneOn(raised, inkRatio, preferred: 8);
    final inkSoft = toneOn(raised, 7, preferred: 35);
    final outline = toneOn(surface, uiRatio, preferred: 50);

    // Red accent: the flag's own red when it reads on white, derived otherwise.
    final redTone = toneOn(surface, textRatio, preferred: _red.tone);

    // Gold: the flag's own gold; content on it is derived.
    final goldTone = _gold.tone.round();

    return ColorScheme(
      brightness: Brightness.light,
      primary: _t(neutral, 6),
      onPrimary: _t(neutral, toneOn(6, inkRatio, preferred: 100)),
      primaryContainer: _t(neutral, 92),
      onPrimaryContainer: _t(neutral, ink),
      secondary:
          redTone == _red.tone.round() ? FlagColors.red : _t(red, redTone),
      onSecondary:
          _t(neutral, toneOn(redTone.toDouble(), textRatio, preferred: 100)),
      secondaryContainer: _t(red, 92),
      onSecondaryContainer: _t(red, toneOn(92, 9, preferred: 15)),
      tertiary: FlagColors.gold,
      onTertiary: _t(neutral, toneOn(goldTone.toDouble(), 9, preferred: 8)),
      tertiaryContainer: _t(gold, 95),
      onTertiaryContainer: _t(gold, toneOn(95, 9, preferred: 15)),
      error: _t(red, toneOn(surface, textRatio, preferred: 40)),
      onError: _t(neutral, 100),
      // Darker than the gold container, so success and error differ in
      // lightness as well as hue (colour-blind safe).
      errorContainer: _t(red, 88),
      onErrorContainer: _t(red, toneOn(88, 9, preferred: 15)),
      surface: _t(neutral, 100),
      onSurface: _t(neutral, ink),
      onSurfaceVariant: _t(neutralVariant, inkSoft),
      surfaceContainerLowest: _t(neutral, 100),
      surfaceContainerLow: _t(neutral, 98),
      surfaceContainer: _t(neutral, 95),
      surfaceContainerHigh: _t(neutral, 92),
      surfaceContainerHighest: _t(neutral, raised.round()),
      outline: _t(neutralVariant, outline),
      outlineVariant: _t(neutral, 86),
      inverseSurface: _t(neutral, 8),
      onInverseSurface: _t(neutral, 98),
      inversePrimary: FlagColors.gold,
      shadow: FlagColors.black,
      scrim: FlagColors.black,
    );
  }

  ColorScheme _dark() {
    const surface = 8.0;
    const raised = 20.0; // the lightest surface text is ever placed on

    final ink = toneOn(raised, inkRatio, preferred: 96);
    final inkSoft = toneOn(raised, 7, preferred: 80);
    final outline = toneOn(surface, uiRatio, preferred: 60);

    // Accent: gold glows on black. Red is lifted in tone (same hue) until it
    // reads as text on the dark surface.
    final redTone = toneOn(raised, textRatio, preferred: 70);
    // Error uses the darkest tone that still reads as text on the dark surface
    // (error text is only placed on the page and card, never on raised fills).
    // Keeping it well below the gold's tone means success and error differ in
    // lightness too, which is what survives red-green colour blindness.
    final errorTone = toneOn(surface, textRatio);
    final goldTone = _gold.tone.round();

    return ColorScheme(
      brightness: Brightness.dark,
      primary: FlagColors.gold,
      onPrimary:
          _t(neutral, toneOn(goldTone.toDouble(), inkRatio, preferred: 8)),
      primaryContainer: _t(neutral, 22),
      onPrimaryContainer: _t(neutral, 100),
      secondary: _t(red, redTone),
      onSecondary:
          _t(neutral, toneOn(redTone.toDouble(), textRatio, preferred: 8)),
      secondaryContainer: _t(red, 22),
      onSecondaryContainer: _t(red, toneOn(22, 9, preferred: 90)),
      tertiary: FlagColors.gold,
      onTertiary: _t(neutral, toneOn(goldTone.toDouble(), 9, preferred: 8)),
      tertiaryContainer: _t(gold, 30),
      onTertiaryContainer: _t(gold, toneOn(30, 9, preferred: 94)),
      error: _t(red, errorTone),
      onError:
          _t(neutral, toneOn(errorTone.toDouble(), textRatio, preferred: 8)),
      errorContainer: _t(red, 16),
      onErrorContainer: _t(red, toneOn(16, 9, preferred: 92)),
      surface: _t(neutral, surface.round()),
      onSurface: _t(neutral, ink),
      onSurfaceVariant: _t(neutralVariant, inkSoft),
      surfaceContainerLowest: FlagColors.black,
      surfaceContainerLow: _t(neutral, 5),
      surfaceContainer: _t(neutral, 11),
      surfaceContainerHigh: _t(neutral, 15),
      surfaceContainerHighest: _t(neutral, raised.round()),
      outline: _t(neutralVariant, outline),
      outlineVariant: _t(neutral, 24),
      inverseSurface: _t(neutral, 96),
      onInverseSurface: _t(neutral, 8),
      inversePrimary: _t(neutral, 8),
      shadow: FlagColors.black,
      scrim: FlagColors.black,
    );
  }
}
