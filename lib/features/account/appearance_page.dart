import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/haptics.dart';
import '../../shared/widgets/app_widgets.dart';

/// Light, dark or the device's own setting. The choice applies to the whole app
/// as soon as it is made.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appControllerProvider).profile!;
    final theme = Theme.of(context);

    return SettingsPage(
      title: 'Appearance',
      subtitle: 'Warm paper by day, charcoal by night.',
      children: [
        SettingsSection(
          title: 'Color mode',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppearancePreference>(
                  showSelectedIcon: true,
                  segments: const [
                    ButtonSegment(
                      value: AppearancePreference.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Device'),
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
                    ref.read(appControllerProvider).updateProfile(
                        profile.copyWith(appearancePreference: value.first));
                  },
                ),
              ),
            ),
          ],
        ),
        if (MediaQuery.highContrastOf(context))
          Text(
            'Your device is set to increase contrast, so Sprichst keeps its '
            'surfaces opaque.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}
