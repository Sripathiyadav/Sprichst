import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'auth_errors.dart';
import 'auth_view_model.dart';

class AuthView extends ConsumerWidget {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSigningIn = ref.watch(signInInProgressProvider);
    final error = ref.watch(signInErrorProvider) ??
        (ref.watch(authViewModelProvider).hasError
            ? describeAuthError(ref.watch(authViewModelProvider).error!)
            : null);
    final theme = Theme.of(context);

    return GlassPage(
      body: CenteredScroll(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SPRICHST',
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.xs),
            const SizedBox(width: 120, child: FlagStripe(height: 8)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Deutsch lernen.\nDeutsch sprechen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Sign in to continue', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSigningIn
                    ? null
                    : () => ref
                        .read(authViewModelProvider.notifier)
                        .signInWithGoogle(),
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (isSigningIn) ...[
              const SizedBox(height: AppSpacing.xl),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
