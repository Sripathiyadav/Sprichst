import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'color_system.dart';
import 'glass_theme.dart';

export 'color_system.dart';
export 'glass_theme.dart';

/// Design tokens and Material themes used across the application.
///
/// Universal-design rules the palette follows:
/// - every text/background pair reaches WCAG AA (enforced by a test);
/// - colour never carries meaning alone: success, error, and selection always
///   come with an icon or a word as well;
/// - light mode is white with a black primary action and a red accent; dark
///   mode is flag-black with a gold primary action, so the strongest control on
///   any screen is also the highest-contrast one.
abstract final class SprichstTheme {
  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  /// The app theme for [brightness]. [glass] carries the learner's surface
  /// style and intensity so any widget can read it with `context.glass`.
  static ThemeData build(
    Brightness brightness, {
    GlassTheme glass = GlassTheme.standard,
  }) =>
      _theme(brightness, glass);

  static ThemeData _theme(Brightness brightness, GlassTheme glass) {
    final palette = SprichstPalette.flag;
    final scheme = palette.scheme(brightness);
    final isDark = brightness == Brightness.dark;
    final background = palette.background(brightness);
    // The platform's own type (San Francisco on Apple devices, Roboto
    // elsewhere) underneath our scale. Material merges this into the app text
    // theme anyway; doing it here too gives the styles we hand to buttons and
    // list tiles directly the same font, so every label matches.
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    final text = (isDark ? typography.white : typography.black)
        .merge(_textTheme(scheme));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: text,
      // 48dp minimum targets and standard density: size and space for approach.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        // Transparent: pages draw their own backdrop (GlassPage), and a flat
        // bar over a glowing body would show a seam.
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        // A hairline border, not a shadow, separates cards in both modes.
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // A disabled button stays legible (it still names the next step)
          // rather than fading to near-invisible.
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
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
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline, width: 1.5),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: isDark ? scheme.primary : scheme.secondary,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          disabledForegroundColor: scheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: _inputBorder(scheme.outline),
        enabledBorder: _inputBorder(scheme.outline),
        focusedBorder: _inputBorder(scheme.onSurface, width: 2.5),
        errorBorder: _inputBorder(scheme.error, width: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          // The selected segment matches the navigation indicator: gold on
          // dark surfaces, the soft red tint on light ones.
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            if (!selected) return Colors.transparent;
            return isDark ? scheme.primary : scheme.secondaryContainer;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (!states.contains(WidgetState.selected)) return scheme.onSurface;
            return isDark ? scheme.onPrimary : scheme.onSecondaryContainer;
          }),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outline),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // The selected pill carries the flag's red in light mode, gold in dark.
        indicatorColor: isDark ? scheme.primary : scheme.secondaryContainer,
        // Labels stay visible: icons alone are not self-explanatory.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) && isDark
                  ? scheme.onPrimary
                  : scheme.onSurface,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => text.labelMedium?.copyWith(
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: scheme.onSurface,
                )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: isDark ? scheme.primary : scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(
          color: isDark ? scheme.onPrimary : scheme.onSurface,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurface),
        selectedLabelTextStyle:
            text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: text.labelMedium,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.xs,
        iconColor: scheme.onSurface,
        subtitleTextStyle: text.bodyMedium,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(scheme.onSurface),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHighest),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: isDark ? scheme.primary : scheme.secondary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: isDark ? scheme.primary : scheme.secondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? scheme.primary : scheme.secondary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      focusColor: scheme.onSurface.withValues(alpha: .12),
      extensions: [glass],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Apple's text styles (Human Interface Guidelines) by role: Large Title 34,
  /// Title 2 22, Title 3 20, Headline 17 semibold, Body 17, Subheadline 15,
  /// Footnote 13, Caption 12. Hierarchy comes from size and weight, not colour.
  /// Nothing here caps the system text scale, so people who enlarge text in
  /// device settings (Dynamic Type) get larger text.
  static TextTheme _textTheme(ColorScheme scheme) {
    final strong = scheme.onSurface;
    final soft = scheme.onSurfaceVariant;
    return TextTheme(
      displaySmall: TextStyle(
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: strong),
      headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: strong),
      titleLarge: TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: strong),
      titleMedium: TextStyle(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: strong),
      bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: strong),
      bodyMedium: TextStyle(fontSize: 15, height: 1.4, color: soft),
      bodySmall: TextStyle(fontSize: 13, height: 1.35, color: soft),
      labelLarge: const TextStyle(
          fontSize: 17, height: 1.2, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
          fontSize: 13,
          height: 1.25,
          fontWeight: FontWeight.w500,
          color: strong),
      labelSmall: TextStyle(
          fontSize: 12, height: 1.25, fontWeight: FontWeight.w500, color: soft),
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
}

abstract final class AppRadius {
  static const input = 14.0;
  static const control = 14.0;
  static const card = 20.0;
}

abstract final class AppSize {
  /// Height of primary controls; comfortably above the 48dp minimum target.
  static const control = 52.0;
}

extension SprichstColors on BuildContext {
  ColorScheme get _scheme => Theme.of(this).colorScheme;
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  /// The colour for emphasis such as progress and selection: red on light
  /// surfaces, gold on dark ones (each is high-contrast against its surface).
  Color get accent => _isDark ? _scheme.primary : _scheme.secondary;
  Color get onAccent => _isDark ? _scheme.onPrimary : _scheme.onSecondary;

  /// A quiet raised surface for secondary content and avatars.
  Color get softSurface => _scheme.surfaceContainerHigh;

  /// Correct answers and achievements (gold).
  Color get successSurface => _scheme.tertiaryContainer;
  Color get onSuccessSurface => _scheme.onTertiaryContainer;

  /// Mistakes and destructive actions (red).
  Color get dangerSurface => _scheme.errorContainer;
  Color get onDangerSurface => _scheme.onErrorContainer;
}
