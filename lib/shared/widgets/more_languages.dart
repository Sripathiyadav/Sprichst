import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Sprichst teaches German today. This says so, and that more languages are
/// coming, without promising which ones or when. With [onRequest] it offers a
/// way to say which language the learner wants.
class MoreLanguagesNote extends StatelessWidget {
  const MoreLanguagesNote({super.key, this.onRequest});

  final VoidCallback? onRequest;

  static const title = 'More languages coming soon';
  static const body =
      'Sprichst teaches German today. More languages are on the way.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return DecoratedBox(
      key: const ValueKey('more-languages'),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.public, color: t.ink, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(body,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: t.inkMuted)),
                  if (onRequest != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const ValueKey('request-language'),
                        onPressed: onRequest,
                        child: const Text('Request a language'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
