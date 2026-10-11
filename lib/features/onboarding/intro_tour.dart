import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/lottie_view.dart';

/// One page of the tour: a picture, a short label, a heading and two plain
/// sentences.
class TourPageData {
  const TourPageData({
    required this.animation,
    required this.label,
    required this.title,
    required this.body,
  });

  final String animation;
  final String label;
  final String title;
  final String body;
}

/// What Sprichst does and how it is built, in five screens. Every claim here is
/// something the app really does; the tests keep the list at five pages.
const tourPages = <TourPageData>[
  TourPageData(
    animation: 'tour_lessons',
    label: 'LEARN',
    title: 'One clear next step',
    body:
        'Short lessons build on each other from your first words up. Home always shows what to do next, so you never have to choose from a long menu.',
  ),
  TourPageData(
    animation: 'tour_coach',
    label: 'TALK',
    title: 'A coach that explains why',
    body:
        'Write or speak with the AI coach. It corrects you gently, tells you why, and remembers the last few messages so it does not repeat itself.',
  ),
  TourPageData(
    animation: 'tour_review',
    label: 'REMEMBER',
    title: 'Practice that comes back',
    body:
        'Words and mistakes return a little later each time you get them right, so what you learn stays learned.',
  ),
  TourPageData(
    animation: 'tour_private',
    label: 'PRIVATE',
    title: 'Your words stay yours',
    body:
        'The coach runs on your phone. For stronger answers you can bring your own key from Groq, Gemini, OpenAI, Claude, Grok and more; it stays on your device. Sprichst runs no AI server and sells or tracks nothing. Set it up any time in Account → AI & voice.',
  ),
  TourPageData(
    animation: 'tour_design',
    label: 'DESIGN',
    title: 'Calm, clear and yours',
    body:
        'Paper-and-ink screens with one main action each. Status is always a word and an icon, never colour alone. Text scales with your settings, and motion stops when you turn on Reduce Motion.',
  ),
];

/// The tour: swipe or use the buttons; "Skip" leaves at any point. Used in
/// onboarding and again from Account → How Sprichst works.
class IntroTour extends StatefulWidget {
  const IntroTour({
    super.key,
    required this.onDone,
    this.finishLabel = 'Continue',
    this.pages = tourPages,
  });

  /// Called after the last page, or when the learner skips.
  final VoidCallback onDone;
  final String finishLabel;
  final List<TourPageData> pages;

  @override
  State<IntroTour> createState() => _IntroTourState();
}

class _IntroTourState extends State<IntroTour> {
  var _index = 0;
  var _forward = true;

  bool get _last => _index == widget.pages.length - 1;

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0) return;
    if (next >= widget.pages.length) {
      widget.onDone();
      return;
    }
    setState(() {
      _forward = delta > 0;
      _index = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final page = widget.pages[_index];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Swiping is a convenience; the buttons do everything it does.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -300) _go(1);
        if (v > 300) _go(-1);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('HOW SPRICHST WORKS',
                    style: theme.textTheme.labelSmall),
              ),
              TextButton(
                key: const ValueKey('tour-skip'),
                onPressed: widget.onDone,
                child: const Text('Skip'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: motionDuration(context, 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(_forward ? .06 : -.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(_index),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: t.line),
                  ),
                  child: Center(
                    child: SprichstLottie(
                      page.animation,
                      width: 240,
                      height: 180,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('${page.label} · ${_index + 1} OF ${widget.pages.length}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: t.inkMuted)),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  header: true,
                  child:
                      Text(page.title, style: theme.textTheme.headlineMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(page.body,
                    style:
                        theme.textTheme.bodyLarge?.copyWith(color: t.inkMuted)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Dots(count: widget.pages.length, index: _index),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (_index > 0) ...[
                OutlinedButton(
                  key: const ValueKey('tour-back'),
                  onPressed: () => _go(-1),
                  child: const Text('Back'),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: PrimaryButton(
                  key: const ValueKey('tour-next'),
                  label: _last ? widget.finishLabel : 'Next',
                  block: true,
                  onPressed: () => _go(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Progress through the tour. The page count is in the text above as well, so
/// the dots are decoration for sighted users and are not read out.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: motionDuration(context, 200),
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? t.coral : t.lineStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
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
