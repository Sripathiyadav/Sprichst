import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'auth_view_model.dart';

class AuthView extends ConsumerWidget {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: CenteredScroll(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SPRICHST',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
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
                onPressed: authState.isLoading
                    ? null
                    : () => ref
                        .read(authViewModelProvider.notifier)
                        .signInWithGoogle(),
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
            ),
            if (authState.hasError) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sign-in failed:\n${authState.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (authState.isLoading) ...[
              const SizedBox(height: AppSpacing.xl),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
