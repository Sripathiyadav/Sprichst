import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../legal/legal_view.dart';
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

    final t = context.tokens;

    return GlassPage(
      body: Stack(
        children: [
          // Coral shapes bleeding off the top-right corner: decoration only.
          const Positioned(
            right: -70,
            top: -50,
            child: Geometry(shape: GeometryShape.disc, size: 220),
          ),
          const Positioned(
            right: 40,
            top: 110,
            child: Geometry(shape: GeometryShape.ring, size: 96),
          ),
          CenteredScroll(
            maxWidth: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.huge),
                const Wordmark(size: 40),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Deutsch lernen.\nDeutsch sprechen.',
                  locale: const Locale('de'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                Text('SIGN IN TO CONTINUE', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: 'Continue with Google',
                  block: true,
                  onPressed: isSigningIn
                      ? null
                      : () => ref
                          .read(authViewModelProvider.notifier)
                          .signInWithGoogle(),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FeedbackBanner(
                    tone: BannerTone.danger,
                    title: 'Couldn’t sign in',
                    message: error,
                  ),
                ],
                if (isSigningIn) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const StateMessage(
                    kind: StateKind.loading,
                    title: 'Signing in',
                    message: 'Waiting for Google.',
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'By continuing you agree to the Terms and confirm you have read the Privacy Policy. '
                  'No analytics, no tracking, no ads.',
                  style: theme.textTheme.bodySmall?.copyWith(color: t.inkMuted),
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () =>
                          openLegalDocument(context, 'terms-of-service'),
                      child: const Text('Terms'),
                    ),
                    TextButton(
                      onPressed: () =>
                          openLegalDocument(context, 'privacy-policy'),
                      child: const Text('Privacy Policy'),
                    ),
                    TextButton(
                      onPressed: () => openLegalDocument(context, 'impressum'),
                      child: const Text('Impressum'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
