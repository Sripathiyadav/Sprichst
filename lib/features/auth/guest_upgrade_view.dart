import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'guest_mode.dart';

/// Shown once, right after a guest signs in: moves the progress kept on this
/// device into the account. When the account already has progress of its own
/// the learner picks which to keep; nothing is dropped before they choose.
class GuestUpgradeView extends ConsumerStatefulWidget {
  const GuestUpgradeView({super.key});

  @override
  ConsumerState<GuestUpgradeView> createState() => _GuestUpgradeViewState();
}

class _GuestUpgradeViewState extends ConsumerState<GuestUpgradeView> {
  LearningProfile? _device;
  LearningProfile? _account;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    try {
      final device = await ref.read(guestRepositoryProvider).loadProfile();
      if (device == null) return await _finish();
      final account = await ref.read(accountRepositoryProvider).loadProfile();
      if (account == null) return await _finish(keep: device);
      if (mounted) {
        setState(() {
          _device = device;
          _account = account;
        });
      }
    } catch (_) {
      // Offline, most likely. The device copy is untouched; try again.
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Saves [keep] to the account (null keeps what the account has), then
  /// clears the device copy and leaves guest mode.
  Future<void> _finish({LearningProfile? keep}) async {
    try {
      if (keep != null) {
        final account = ref.read(accountRepositoryProvider);
        await account.saveProfile(keep);
        await account.flush();
      }
      await ref.read(guestRepositoryProvider).deleteLearningData();
      await ref.read(guestModeProvider.notifier).end();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final account = _account;
    final theme = Theme.of(context);

    return GlassPage(
      body: CenteredScroll(
        maxWidth: 420,
        child: _failed
            ? StateMessage(
                kind: StateKind.error,
                title: 'Couldn’t reach your account',
                message:
                    'Your progress is still on this device. Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: _start,
              )
            : device == null || account == null
                ? const StateMessage(
                    kind: StateKind.loading,
                    title: 'Moving your progress',
                    message: 'Saving what you learned to your account.',
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Which progress should we keep?',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                          'This account already has progress. Pick one; the other is replaced.'),
                      const SizedBox(height: AppSpacing.xl),
                      _Choice(
                        key: const ValueKey('keep-account'),
                        title: 'Keep account progress',
                        profile: account,
                        onTap: () => _finish(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _Choice(
                        key: const ValueKey('keep-device'),
                        title: 'Use this device’s progress',
                        profile: device,
                        onTap: () => _finish(keep: device),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {super.key,
      required this.title,
      required this.profile,
      required this.onTap});

  final String title;
  final LearningProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lessons = profile.completedLessonCount;
    return SettingsTile(
      icon: Icons.check_circle_outline,
      title: title,
      subtitle:
          '${profile.currentLevel.label} · $lessons lesson${lessons == 1 ? '' : 's'} done · ${profile.xp} XP',
      onTap: onTap,
    );
  }
}
