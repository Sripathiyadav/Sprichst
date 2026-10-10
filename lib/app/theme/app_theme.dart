import 'package:flutter/material.dart';

import 'color_system.dart';
import 'glass_theme.dart';

export 'color_system.dart';
export 'glass_theme.dart';

/// Material themes built from the design system's tokens (see
/// [SprichstTokens]).
///
/// Rules the theme keeps:
/// - every text/background pair reaches WCAG AA (enforced by a test);
/// - colour never carries meaning alone: success, error, and selection always
///   come with an icon or a word as well;
/// - one primary action per screen: charcoal in light mode, coral in dark, so
///   the strongest control is also the highest-contrast one.
abstract final class SprichstTheme {
  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  /// The family of the design system, bundled with the app.
  static const fontFamily = 'Figtree';
  static const fontFallback = ['Roboto'];

  /// The app theme for [brightness]. [glass] carries the learner's surface
  /// style and intensity so any widget can read it with `context.glass`.
  static ThemeData build(
    Brightness brightness, {
    GlassTheme glass = GlassTheme.standard,
  }) =>
      _theme(brightness, glass);

  static ThemeData _theme(Brightness brightness, GlassTheme glass) {
    final tokens = SprichstTokens.of(brightness);
    final scheme = tokens.scheme;
    // The family goes on every style here, because buttons and list tiles take
    // these styles directly instead of the merged theme text.
    final text = _textTheme(tokens)
        .apply(fontFamily: fontFamily, fontFamilyFallback: fontFallback);
    final radius = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: tokens.line));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: tokens.canvas,
      canvasColor: tokens.canvas,
      textTheme: text,
      // 48dp minimum targets and standard density: size and space for approach.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        // Transparent: pages draw their own masthead and backdrop.
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: radius,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.action,
          foregroundColor: tokens.onAction,
          // A disabled button stays legible (it still names the next step)
          // rather than fading to near-invisible.
          disabledBackgroundColor: tokens.surfaceSunken,
          disabledForegroundColor: tokens.inkMuted,
          minimumSize: const Size(64, AppSize.control),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSize.control),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge,
          foregroundColor: tokens.ink,
          side: BorderSide(color: tokens.lineStrong, width: 1.5),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tokens.accent,
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tokens.ink,
          disabledForegroundColor: tokens.inkMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: tokens.inkMuted),
        labelStyle: text.bodyMedium?.copyWith(color: tokens.inkMuted),
        border: _inputBorder(tokens.lineStrong),
        enabledBorder: _inputBorder(tokens.lineStrong),
        focusedBorder: _inputBorder(tokens.ink, width: 2.5),
        errorBorder: _inputBorder(tokens.danger, width: 2),
        focusedErrorBorder: _inputBorder(tokens.danger, width: 2.5),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: WidgetStatePropertyAll(BorderSide(color: tokens.lineStrong)),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? tokens.accentSoft
                  : Colors.transparent),
          foregroundColor: WidgetStatePropertyAll(tokens.ink),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: tokens.lineStrong),
        backgroundColor: Colors.transparent,
        selectedColor: tokens.accentSoft,
        labelStyle: text.labelMedium?.copyWith(color: tokens.ink),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSize.nav,
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: tokens.accentSoft,
        // Labels stay visible: icons alone are not self-explanatory.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: tokens.ink)),
        labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => text.labelMedium?.copyWith(
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: tokens.ink,
                )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.accentSoft,
        selectedIconTheme: IconThemeData(color: tokens.ink),
        unselectedIconTheme: IconThemeData(color: tokens.ink),
        selectedLabelTextStyle: text.labelMedium
            ?.copyWith(fontWeight: FontWeight.w700, color: tokens.ink),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: tokens.ink),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.xs,
        iconColor: tokens.ink,
        titleTextStyle: text.labelLarge?.copyWith(color: tokens.ink),
        subtitleTextStyle: text.bodyMedium?.copyWith(color: tokens.inkMuted),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(tokens.ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? tokens.onAction
                : tokens.lineStrong),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? tokens.action
                : tokens.surfaceSunken),
        trackOutlineColor: WidgetStatePropertyAll(tokens.lineStrong),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.accent,
        inactiveTrackColor: tokens.surfaceSunken,
        thumbColor: tokens.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.panel,
        contentTextStyle: text.bodyMedium?.copyWith(color: tokens.onPanel),
        actionTextColor: tokens.accentOnPanel,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: radius,
      ),
      dividerTheme: DividerThemeData(color: tokens.line, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.surfaceSunken,
      ),
      focusColor: tokens.ink.withValues(alpha: .12),
      extensions: [glass, tokens],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );

  /// The design system's type scale (Figtree). Editorial styles carry the look,
  /// light numerals and medium headings with tight tracking at large sizes; the
  /// interface styles do the work. Nothing caps the system text scale. Letter
  /// spacing is in logical pixels: each em value times the font size.
  static TextTheme _textTheme(SprichstTokens t) {
    const tabular = [FontFeature.tabularFigures()];
    return TextTheme(
      // numeral-hero: the one big number on a screen.
      displayLarge: TextStyle(
          fontSize: 120,
          height: .9,
          fontWeight: FontWeight.w300,
          letterSpacing: -4.8,
          fontFeatures: tabular,
          color: t.ink),
      // numeral: numbers inside a panel or beside a disc.
      displayMedium: TextStyle(
          fontSize: 64,
          height: 1,
          fontWeight: FontWeight.w300,
          letterSpacing: -1.92,
          fontFeatures: tabular,
          color: t.ink),
      // display: greeting, lesson-intro title. One per screen.
      displaySmall: TextStyle(
          fontSize: 40,
          height: 1.1,
          fontWeight: FontWeight.w500,
          letterSpacing: -.8,
          color: t.ink),
      // stat: counts in cards.
      headlineLarge: TextStyle(
          fontSize: 40,
          height: 1,
          fontWeight: FontWeight.w300,
          letterSpacing: -.8,
          fontFeatures: tabular,
          color: t.ink),
      // title: screen and panel titles.
      headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.21,
          fontWeight: FontWeight.w500,
          letterSpacing: -.28,
          color: t.ink),
      // prompt: the German text under study.
      headlineSmall: TextStyle(
          fontSize: 24,
          height: 1.33,
          fontWeight: FontWeight.w500,
          color: t.ink),
      // headline: card titles, dialog titles.
      titleLarge: TextStyle(
          fontSize: 22,
          height: 1.27,
          fontWeight: FontWeight.w600,
          color: t.ink),
      titleMedium: TextStyle(
          fontSize: 18, height: 1.3, fontWeight: FontWeight.w600, color: t.ink),
      titleSmall: TextStyle(
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: t.ink),
      // body-lg: lesson content, explanations, tutor messages.
      bodyLarge: TextStyle(fontSize: 18, height: 1.56, color: t.ink),
      // body: default interface text.
      bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: t.ink),
      // caption: metadata, helper text.
      bodySmall: TextStyle(
          fontSize: 13,
          height: 1.38,
          fontWeight: FontWeight.w500,
          color: t.inkMuted),
      // label: buttons, tabs, tiles.
      labelLarge: const TextStyle(
          fontSize: 16, height: 1.25, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
          fontSize: 13,
          height: 1.38,
          fontWeight: FontWeight.w500,
          color: t.ink),
      // eyebrow: written in capitals in the string.
      labelSmall: TextStyle(
          fontSize: 13,
          height: 1.23,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.04,
          color: t.inkMuted),
    );
  }
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const huge = 64.0;
}

abstract final class AppRadius {
  static const input = 14.0;
  static const control = 14.0;
  static const card = 20.0;
  static const panel = 28.0;
}

abstract final class AppSize {
  /// Height of primary controls; comfortably above the 48dp minimum target.
  static const control = 52.0;

  /// Height of the bottom navigation bar.
  static const nav = 72.0;
}

extension SprichstColors on BuildContext {
  ColorScheme get _scheme => Theme.of(this).colorScheme;

  /// Interactive coral as text and marks: links, quiet buttons, progress fills.
  Color get accent => _scheme.secondary;
  Color get onAccent => _scheme.onSecondary;

  /// A quiet raised surface for secondary content and avatars.
  Color get softSurface => _scheme.surfaceContainerHigh;

  /// Correct answers and completed work (teal, never the red-green axis).
  Color get successSurface => _scheme.tertiaryContainer;
  Color get onSuccessSurface => _scheme.onTertiaryContainer;

  /// Mistakes and destructive actions (crimson).
  Color get dangerSurface => _scheme.errorContainer;
  Color get onDangerSurface => _scheme.onErrorContainer;
}
