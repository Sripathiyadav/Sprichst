import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'auth_view_model.dart';

/// Tells a guest their progress is on this device only, with a way to add an
/// account. Signing in moves the progress there (see `GuestUpgradeView`).
class GuestSyncCard extends ConsumerWidget {
  const GuestSyncCard({super.key, this.onDismiss});

  /// Shows a close button when set (the Home banner).
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSigningIn = ref.watch(signInInProgressProvider);
    final error = ref.watch(signInErrorProvider);

    return SoftCard(
      color: context.softSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.phone_iphone_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress on this device only',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    const Text(
                        'Add an account to keep it safe and use it on other devices.'),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  tooltip: 'Hide',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: isSigningIn ? 'Signing in…' : 'Sign in to sync',
            onPressed: isSigningIn
                ? null
                : () =>
                    ref.read(authViewModelProvider.notifier).signInWithGoogle(),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(error,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
