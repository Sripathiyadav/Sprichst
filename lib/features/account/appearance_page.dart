import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/haptics.dart';
import '../../shared/widgets/app_widgets.dart';

/// Colour mode, interface style, and Liquid Glass intensity, with a live
/// preview. Choices apply to the whole app as soon as they are made.
class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  /// Follows the slider while it is dragged; the profile is saved on release so
  /// we do not write to the database on every pixel of movement.
  late double _intensity =
      ref.read(appControllerProvider).profile!.glassIntensity.toDouble();

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(appControllerProvider).profile!;
    final theme = Theme.of(context);
    final isGlass = profile.surfaceStyle == SurfaceStyle.glass;

    return SettingsPage(
      title: 'Appearance',
      subtitle: 'Choose how Sprichst looks: light or dark, and how its '
          'surfaces are drawn.',
      children: [
        SettingsSection(
          title: 'Color mode',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppearancePreference>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AppearancePreference.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Auto'),
                    ),
                    ButtonSegment(
                      value: AppearancePreference.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: AppearancePreference.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {profile.appearancePreference},
                  onSelectionChanged: (value) {
                    Haptics.selection();
                    _save(profile.copyWith(appearancePreference: value.first));
                  },
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Interface style',
          description: isGlass
              ? SurfaceStyle.glass.description
              : SurfaceStyle.standard.description,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<SurfaceStyle>(
                  showSelectedIcon: false,
                  segments: [
                    for (final style in SurfaceStyle.values)
                      ButtonSegment(
                        value: style,
                        icon: Icon(style == SurfaceStyle.glass
                            ? Icons.blur_on
                            : Icons.crop_square),
                        label: Text(style.label),
                      ),
                  ],
                  selected: {profile.surfaceStyle},
                  onSelectionChanged: (value) {
                    Haptics.selection();
                    _save(profile.copyWith(surfaceStyle: value.first));
                  },
                ),
              ),
            ),
            if (isGlass)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Glass intensity',
                              style: theme.textTheme.titleMedium),
                        ),
                        Text('${_intensity.round()}%',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                    Slider(
                      value: _intensity,
                      max: 100,
                      divisions: 20,
                      label: '${_intensity.round()}%',
                      semanticFormatterCallback: (value) =>
                          '${value.round()} percent',
                      onChanged: (value) => setState(() => _intensity = value),
                      onChangeEnd: (value) => _save(
                          profile.copyWith(glassIntensity: value.round())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtle', style: theme.textTheme.bodySmall),
                        Text('Strong', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        _Preview(style: profile.surfaceStyle, intensity: _intensity.round()),
        if (MediaQuery.highContrastOf(context))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              'Your device is set to increase contrast, so Sprichst shows '
              'opaque surfaces whatever you choose here.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Future<void> _save(LearningProfile updated) =>
      ref.read(appControllerProvider).updateProfile(updated);
}

/// A small scene that shows the chosen style at the chosen strength: coloured
/// light behind, a glass bar and card in front. It renders with its own theme
/// extension, so it reflects the slider live, before anything is saved.
class _Preview extends StatelessWidget {
  const _Preview({required this.style, required this.intensity});

  final SurfaceStyle style;
  final int intensity;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final theme = base.copyWith(
      extensions: [GlassTheme.fromProfile(style, intensity)],
    );
    return Semantics(
      label: 'Preview of ${style.label}'
          '${style == SurfaceStyle.glass ? ' at $intensity percent' : ''}',
      excludeSemantics: true,
      child: Theme(
        data: theme,
        child: Builder(
          builder: (context) => ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: SizedBox(
              height: 180,
              child: AmbientBackground(
                child: Stack(
                  children: [
                    // Bright shapes for the glass to pick up.
                    Positioned(
                      left: 24,
                      top: 20,
                      child: _blob(FlagColors.red, 70),
                    ),
                    Positioned(
                      right: 32,
                      bottom: 18,
                      child: _blob(FlagColors.gold, 84),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: GlassSurface(
                          blur: true,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              const Icon(Icons.translate),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Guten Tag!',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text('Preview',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) => DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: SizedBox(width: size, height: size),
      );
}
