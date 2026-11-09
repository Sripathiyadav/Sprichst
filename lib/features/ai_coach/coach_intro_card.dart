import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/lottie_view.dart';

/// Whether the learner has closed the coach guide. Null while it is read.
final coachIntroSeenProvider =
    NotifierProvider<CoachIntroSeen, bool?>(CoachIntroSeen.new);

class CoachIntroSeen extends Notifier<bool?> {
  static const _key = 'sprichst_coach_intro_seen_v1';

  @override
  bool? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    var seen = false;
    try {
      seen = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {}
    state ??= seen;
  }

  Future<void> markSeen() async {
    state = true;
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, true);
    } catch (_) {}
  }
}

/// The first time the Coach opens: a short animation of the settings button
/// and the two ways to power the coach, then how to use it. Shown until the
/// learner closes it.
class CoachIntroCard extends ConsumerWidget {
  const CoachIntroCard({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(coachIntroSeenProvider) != false) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final t = context.tokens;

    Widget step(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: t.coral),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SoftCard(
        key: const ValueKey('coach-intro'),
        color: context.softSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              // The Coach tab is built before it is shown; replaying when the
              // tab becomes visible means the learner sees it from the start.
              child: KeyedSubtree(
                key: ValueKey(TickerMode.of(context)),
                child: const SprichstLottie('coach_intro',
                    width: 240, height: 160),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Meet your coach', style: theme.textTheme.titleMedium),
            step(Icons.tune,
                'First, tap the settings button at the top right. Download the coach to this phone (free, works offline) or add your own AI key.'),
            step(Icons.chat_bubble_outline,
                'Then pick a situation below or just type in German. The coach answers, corrects you and says why.'),
            step(Icons.graphic_eq,
                'Use the wave button at the top for voice mode, and Listen on any reply to hear it.'),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Open coach settings',
              block: true,
              onPressed: onOpenSettings,
            ),
            TextButton(
              onPressed: () =>
                  ref.read(coachIntroSeenProvider.notifier).markSeen(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
