import 'package:flutter/material.dart';

/// Sprichst's colours: the design system's tokens, light and dark.
///
/// The look is a well-set e-reader: warm paper ([canvas]), charcoal blocks
/// ([panel]) and one coral shape. Dark is designed on its own, not inverted:
/// the canvas is never pure black, coral is muted a step, and the primary action
/// turns coral so the strongest control is always the highest-contrast one.
///
/// Every text colour documents the grounds it is checked on; `theme_contrast_test`
/// holds those pairs to WCAG AA (4.5:1 text, 3:1 for 24px+ text and controls).
@immutable
class SprichstTokens extends ThemeExtension<SprichstTokens> {
  const SprichstTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceSunken,
    required this.panel,
    required this.line,
    required this.lineStrong,
    required this.lineOnPanel,
    required this.ink,
    required this.inkMuted,
    required this.onPanel,
    required this.onPanelMuted,
    required this.ghost,
    required this.mark,
    required this.coral,
    required this.coralTint,
    required this.action,
    required this.onAction,
    required this.actionGlyph,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentOnPanel,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.articleDerBg,
    required this.articleDerInk,
    required this.articleDieBg,
    required this.articleDieInk,
    required this.articleDasBg,
    required this.articleDasInk,
    required this.brightness,
  });

  final Brightness brightness;

  /// The page behind everything.
  final Color canvas;

  /// Cards, sheets, dialogs, the navigation bar and input fills.
  final Color surface;

  /// Wells: progress tracks, segmented-control tracks, skeletons.
  final Color surfaceSunken;

  /// The charcoal block: at most one featured panel per screen, and the
  /// learner's chat bubble.
  final Color panel;
  final Color line;
  final Color lineStrong;
  final Color lineOnPanel;

  final Color ink;
  final Color inkMuted;
  final Color onPanel;
  final Color onPanelMuted;

  /// Decorative oversized numerals only; never information.
  final Color ghost;

  /// Bars and marks in charts.
  final Color mark;

  /// Brand fill for geometry. As text only from 24px up.
  final Color coral;
  final Color coralTint;

  /// The one primary action per screen, its label and its trailing arrow.
  final Color action;
  final Color onAction;
  final Color actionGlyph;

  /// Interactive coral as text and marks: links, quiet buttons, progress fills.
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color accentOnPanel;

  /// Status colours, each always paired with an icon and a word.
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  final Color articleDerBg;
  final Color articleDerInk;
  final Color articleDieBg;
  final Color articleDieInk;
  final Color articleDasBg;
  final Color articleDasInk;

  static const light = SprichstTokens(
    brightness: Brightness.light,
    canvas: Color(0xFFF2EAE1),
    surface: Color(0xFFFBF7F2),
    surfaceSunken: Color(0xFFE8DED3),
    panel: Color(0xFF363433),
    line: Color(0xFFDDD2C6),
    lineStrong: Color(0xFF8E8379),
    lineOnPanel: Color(0xFF57534F),
    ink: Color(0xFF2A2826),
    inkMuted: Color(0xFF645B54),
    onPanel: Color(0xFFF5EEE6),
    onPanelMuted: Color(0xFFBCB2A9),
    ghost: Color(0xFFD4CABF),
    mark: Color(0xFF3D3A38),
    coral: Color(0xFFE45347),
    coralTint: Color(0xFFF3B5AC),
    action: Color(0xFF2A2826),
    onAction: Color(0xFFFBF7F2),
    actionGlyph: Color(0xFFF2877C),
    accent: Color(0xFFB32F28),
    onAccent: Color(0xFFFFF8F3),
    accentSoft: Color(0xFFFBE6E1),
    accentOnPanel: Color(0xFFF2877C),
    success: Color(0xFF22706A),
    successSoft: Color(0xFFD7EEEA),
    warning: Color(0xFF8A5A00),
    warningSoft: Color(0xFFF6E7C8),
    danger: Color(0xFFA11D3A),
    dangerSoft: Color(0xFFF6DEE2),
    articleDerBg: Color(0xFFCFE5FF),
    articleDerInk: Color(0xFF001D34),
    articleDieBg: Color(0xFFFFDAD6),
    articleDieInk: Color(0xFF410002),
    articleDasBg: Color(0xFFB5F39A),
    articleDasInk: Color(0xFF042100),
  );

  static const dark = SprichstTokens(
    brightness: Brightness.dark,
    canvas: Color(0xFF1F1D1C),
    surface: Color(0xFF2A2827),
    surfaceSunken: Color(0xFF171615),
    panel: Color(0xFF3A3735),
    line: Color(0xFF3B3836),
    lineStrong: Color(0xFF7D736B),
    lineOnPanel: Color(0xFF58534F),
    ink: Color(0xFFF3ECE4),
    inkMuted: Color(0xFFB5ABA2),
    onPanel: Color(0xFFF5EEE6),
    onPanelMuted: Color(0xFFC2B8AF),
    ghost: Color(0xFF45413E),
    mark: Color(0xFF9A9088),
    coral: Color(0xFFD9625A),
    coralTint: Color(0xFF5A302B),
    action: Color(0xFFF08A7F),
    onAction: Color(0xFF241A18),
    actionGlyph: Color(0xFF241A18),
    accent: Color(0xFFF08A7F),
    onAccent: Color(0xFF241A18),
    accentSoft: Color(0xFF4A2724),
    accentOnPanel: Color(0xFFF08A7F),
    success: Color(0xFF6CC9BC),
    successSoft: Color(0xFF173A37),
    warning: Color(0xFFE9B45A),
    warningSoft: Color(0xFF3D2E12),
    danger: Color(0xFFF49AA6),
    dangerSoft: Color(0xFF4A1E27),
    articleDerBg: Color(0xFF004A78),
    articleDerInk: Color(0xFFCFE5FF),
    articleDieBg: Color(0xFF7D2B24),
    articleDieInk: Color(0xFFFFDAD6),
    articleDasBg: Color(0xFF1C520A),
    articleDasInk: Color(0xFFB5F39A),
  );

  static SprichstTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The Material roles the tokens fill (design system → ColorScheme map).
  ColorScheme get scheme {
    final isDark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: action,
      onPrimary: onAction,
      primaryContainer: surfaceSunken,
      onPrimaryContainer: ink,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: accentSoft,
      onSecondaryContainer: ink,
      tertiary: success,
      onTertiary: isDark ? const Color(0xFF0E2926) : const Color(0xFFFFFFFF),
      tertiaryContainer: successSoft,
      onTertiaryContainer: ink,
      error: danger,
      onError: isDark ? const Color(0xFF3A0F18) : const Color(0xFFFFFFFF),
      errorContainer: dangerSoft,
      onErrorContainer: ink,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      surfaceContainerLowest: surface,
      surfaceContainerLow: canvas,
      surfaceContainer: canvas,
      surfaceContainerHigh: Color.lerp(canvas, surfaceSunken, .5)!,
      surfaceContainerHighest: surfaceSunken,
      outline: lineStrong,
      outlineVariant: line,
      inverseSurface: panel,
      onInverseSurface: onPanel,
      inversePrimary: accentOnPanel,
      shadow: const Color(0xFF2A2826),
      scrim: const Color(0xFF000000),
    );
  }

  @override
  SprichstTokens copyWith({Brightness? brightness}) =>
      brightness == null ? this : SprichstTokens.of(brightness);

  @override
  SprichstTokens lerp(SprichstTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SprichstTokens(
      brightness: t < .5 ? brightness : other.brightness,
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      panel: l(panel, other.panel),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      lineOnPanel: l(lineOnPanel, other.lineOnPanel),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      onPanel: l(onPanel, other.onPanel),
      onPanelMuted: l(onPanelMuted, other.onPanelMuted),
      ghost: l(ghost, other.ghost),
      mark: l(mark, other.mark),
      coral: l(coral, other.coral),
      coralTint: l(coralTint, other.coralTint),
      action: l(action, other.action),
      onAction: l(onAction, other.onAction),
      actionGlyph: l(actionGlyph, other.actionGlyph),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentSoft: l(accentSoft, other.accentSoft),
      accentOnPanel: l(accentOnPanel, other.accentOnPanel),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      articleDerBg: l(articleDerBg, other.articleDerBg),
      articleDerInk: l(articleDerInk, other.articleDerInk),
      articleDieBg: l(articleDieBg, other.articleDieBg),
      articleDieInk: l(articleDieInk, other.articleDieInk),
      articleDasBg: l(articleDasBg, other.articleDasBg),
      articleDasInk: l(articleDasInk, other.articleDasInk),
    );
  }
}

/// The design tokens in effect here.
extension SprichstTokensContext on BuildContext {
  SprichstTokens get tokens =>
      Theme.of(this).extension<SprichstTokens>() ??
      SprichstTokens.of(Theme.of(this).brightness);
}
