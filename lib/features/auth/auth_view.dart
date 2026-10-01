import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_view_model.dart';

class AuthView extends ConsumerWidget {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SPRICHTS',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Deutsch lernen.\nDeutsch sprechen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 40),
                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
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
                  const SizedBox(height: 16),
                  Text(
                    'Sign-in failed:\n${authState.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (authState.isLoading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
