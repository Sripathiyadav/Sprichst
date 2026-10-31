import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/lottie_view.dart';

/// One scene of the tour: a short label, a heading and two plain sentences.
class TourPageData {
  const TourPageData({
    required this.label,
    required this.title,
    required this.body,
  });

  final String label;
  final String title;
  final String body;
}

/// What Sprichst does and how it is built, in three scenes of one animation
/// (`assets/lottie/tour_*.json`, 3 s a scene, in this order). Every claim here
/// is something the app really does.
const tourPages = <TourPageData>[
  TourPageData(
    label: 'LEARN',
    title: 'One clear next step',
    body:
        'Short lessons build on each other from your first words up. Home always shows what to do next, so you never have to choose from a long menu.',
  ),
  TourPageData(
    label: 'TALK',
    title: 'A coach that explains why',
    body:
        'Write or speak with the AI coach. It corrects you gently, tells you why, and remembers the last few messages so it does not repeat itself.',
  ),
  TourPageData(
    label: 'PRIVATE',
    title: 'Your words stay yours',
    body:
        'The coach runs on your phone. For stronger answers you can bring your own key from Groq, Gemini, OpenAI, Claude, Grok and more; it stays on your device. Sprichst runs no AI server and sells or tracks nothing.',
  ),
];

/// The tour: one animation that plays its three scenes once, with the words
/// for the scene on screen. The dots replay a scene; "Skip" leaves at any
/// point. Used in onboarding and again from Account → How Sprichst works.
class IntroTour extends StatefulWidget {
  const IntroTour({
    super.key,
    required this.onDone,
    this.finishLabel = 'Continue',
  });

  /// Called by the button, or when the learner skips.
  final VoidCallback onDone;
  final String finishLabel;

  @override
  State<IntroTour> createState() => _IntroTourState();
}

class _IntroTourState extends State<IntroTour>
    with SingleTickerProviderStateMixin {
  static const _scene = Duration(seconds: 3);

  late final _controller =
      AnimationController(vsync: this, duration: _scene * tourPages.length)
        ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _index => (_controller.value * tourPages.length)
      .floor()
      .clamp(0, tourPages.length - 1);

  void _replay(int scene) =>
      _controller.forward(from: scene / tourPages.length);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final still = MediaQuery.disableAnimationsOf(context);

    Widget caption(TourPageData page, int index) => Column(
          key: ValueKey(index),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${page.label} · ${index + 1} OF ${tourPages.length}',
                style: theme.textTheme.labelSmall?.copyWith(color: t.inkMuted)),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              header: true,
              child: Text(page.title, style: theme.textTheme.headlineMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(page.body,
                style: theme.textTheme.bodyLarge?.copyWith(color: t.inkMuted)),
          ],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child:
                  Text('HOW SPRICHST WORKS', style: theme.textTheme.labelSmall),
            ),
            TextButton(
              key: const ValueKey('tour-skip'),
              onPressed: widget.onDone,
              child: const Text('Skip'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.line),
          ),
          child: Center(
            child: SprichstLottie('tour',
                width: 240, height: 180, controller: _controller),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Without motion every scene's words are shown at once.
        if (still)
          for (var i = 0; i < tourPages.length; i++) ...[
            caption(tourPages[i], i),
            const SizedBox(height: AppSpacing.lg),
          ]
        else
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: motionDuration(context, 220),
                  child: caption(tourPages[_index], _index),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Dots(count: tourPages.length, index: _index, onTap: _replay),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        PrimaryButton(
          key: const ValueKey('tour-next'),
          label: widget.finishLabel,
          block: true,
          onPressed: widget.onDone,
        ),
      ],
    );
  }
}

/// Where the animation is. Tapping a dot plays that scene again; the scene's
/// words are on screen as well, so the dots are announced as buttons only.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.onTap});

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            button: true,
            label: 'Play scene ${i + 1} of $count again',
            excludeSemantics: true,
            child: InkResponse(
              key: ValueKey('tour-dot-$i'),
              onTap: () => onTap(i),
              radius: 24,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: AnimatedContainer(
                    duration: motionDuration(context, 200),
                    width: i == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == index ? t.coral : t.lineStrong,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The tour as its own screen, opened from Account.
class IntroTourPage extends StatelessWidget {
  const IntroTourPage({super.key});

  @override
  Widget build(BuildContext context) => GlassPage(
        body: Stack(
          children: [
            CenteredScroll(
              child: IntroTour(
                finishLabel: 'Done',
                onDone: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      );
}
