import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/learning/flashcard_deck.dart';
import '../../domain/learning/flashcard_scheduler.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/speak_button.dart';
import '../games/article_chip.dart';
import '../gamification/reward_news.dart';

/// A spaced-repetition flashcard session.
///
/// Cards start German → meaning; once a card has been recalled twice it flips
/// to meaning → German, because producing a word is a stronger memory test than
/// recognising it. Nouns show without their article on the front, so the
/// article is part of what is recalled.
class FlashcardSessionView extends ConsumerStatefulWidget {
  const FlashcardSessionView({super.key, required this.cards});

  final List<DeckCard> cards;

  @override
  ConsumerState<FlashcardSessionView> createState() =>
      _FlashcardSessionViewState();
}

class _FlashcardSessionViewState extends ConsumerState<FlashcardSessionView> {
  static const _scheduler = FlashcardScheduler();

  late final List<DeckCard> _queue = [...widget.cards];
  final List<CardReview> _reviews = [];
  final _requeued = <String>{};
  var _index = 0;
  var _revealed = false;
  var _saving = false;
  ({int xp, int recalled})? _done;

  DeckCard? get _card => _index < _queue.length ? _queue[_index] : null;

  void _reveal() => setState(() => _revealed = true);

  Future<void> _rate(CardRating rating) async {
    final card = _card;
    if (card == null || !_revealed) return;
    _reviews.add(CardReview(card, rating));
    // A forgotten card comes round once more before the session ends.
    if (rating == CardRating.again && _requeued.add(card.item.id)) {
      _queue.add(card);
    }
    setState(() {
      _index++;
      _revealed = false;
    });
    if (_card == null) await _finish();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    var xp = 0;
    try {
      xp = (await ref.read(appControllerProvider).completeFlashcards(_reviews))
          .xpEarned;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('We could not save this session. Please try again.'),
        ));
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _done =
          (xp: xp, recalled: _reviews.where((r) => r.rating.recalled).length);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _done != null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (!_revealed) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
        _reveal();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final rating = switch (key) {
      LogicalKeyboardKey.digit1 => CardRating.again,
      LogicalKeyboardKey.digit2 => CardRating.hard,
      LogicalKeyboardKey.digit3 => CardRating.good,
      LogicalKeyboardKey.digit4 => CardRating.easy,
      _ => null,
    };
    if (rating == null) return KeyEventResult.ignored;
    _rate(rating);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => GlassPage(
        appBar: const MastheadBar(eyebrow: 'FLASHCARDS'),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: Breakpoints.lessonMaxWidth),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Focus(
                  autofocus: true,
                  onKeyEvent: _onKey,
                  child: AnimatedSwitcher(
                    duration: motionDuration(context),
                    child: _done != null
                        ? _Summary(
                            key: const ValueKey('summary'),
                            total: _reviews.length,
                            recalled: _done!.recalled,
                            xp: _done!.xp,
                          )
                        : _saving
                            ? const StateMessage(
                                kind: StateKind.loading,
                                title: 'Saving your session',
                                message: 'Scheduling your next reviews.',
                              )
                            : _card == null
                                ? const _Empty()
                                : _board(_card!),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _board(DeckCard card) {
    final theme = Theme.of(context);
    final item = card.item;
    final toGerman = card.asksForGerman;
    final state = card.state;
    final t = context.tokens;
    return Column(
      key: ValueKey('card$_index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(
            child: SkillMeter(
              label: 'Card ${_index + 1} of ${_queue.length}',
              value: _index / _queue.length,
              valueLabel: ' ',
              compact: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          DsChip(card.isNew ? 'New word' : 'Review',
              icon: card.isNew ? Icons.fiber_new_outlined : Icons.refresh,
              tone: ChipTone.outline),
        ]),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Semantics(
            button: !_revealed,
            label: _revealed
                ? '${item.display}, meaning ${item.english}'
                : toGerman
                    ? 'How do you say ${item.english} in German? Double tap to show the answer.'
                    : 'What does ${item.german} mean? Double tap to show the answer.',
            excludeSemantics: true,
            onTap: _revealed ? null : _reveal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _revealed ? null : _reveal,
              child: _CardPanel(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (toGerman ? 'In German' : 'What does it mean?')
                          .toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: t.accentOnPanel),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        toGerman ? item.english : item.german,
                        locale: toGerman ? null : const Locale('de'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayMedium
                            ?.copyWith(color: t.onPanel),
                      ),
                    ),
                    if (!_revealed && item.isNoun && !toGerman) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Which article?',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: t.onPanelMuted)),
                    ],
                    if (_revealed) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(height: 1, color: t.lineOnPanel),
                      const SizedBox(height: AppSpacing.lg),
                      if (item.article != null)
                        ArticleChip(item.article!, large: true),
                      if (item.article != null)
                        const SizedBox(height: AppSpacing.xs),
                      Text(
                        toGerman ? item.display : item.english,
                        locale: toGerman ? const Locale('de') : null,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: t.onPanel),
                      ),
                      if (item.example != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(item.example!,
                            locale: const Locale('de'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: t.onPanel)),
                        if (item.exampleEnglish != null)
                          Text(item.exampleEnglish!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: t.onPanelMuted)),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      SpeakButton(
                        text: item.example ?? item.display,
                        label: 'Listen',
                        filled: true,
                        onPanel: true,
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl),
                        child: Text('Tap the card or press Space',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: t.onPanelMuted)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_revealed)
          PrimaryButton(label: 'Show answer', block: true, onPressed: _reveal)
        else
          Row(children: [
            for (final rating in CardRating.values) ...[
              Expanded(
                child: _RatingButton(
                  rating: rating,
                  hint: FlashcardScheduler.describe(
                      _scheduler.interval(state, rating)),
                  shortcut: rating.index + 1,
                  onPressed: () => _rate(rating),
                ),
              ),
              if (rating != CardRating.values.last)
                const SizedBox(width: AppSpacing.xs),
            ],
          ]),
      ],
    );
  }
}

/// The flashcard: a charcoal panel with the hatch in its corner.
class _CardPanel extends StatelessWidget {
  const _CardPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel));
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.panel, shape: shape, shadows: const [
        BoxShadow(
            color: Color(0x59000000),
            blurRadius: 36,
            spreadRadius: -12,
            offset: Offset(0, 18)),
      ]),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Stack(
          children: [
            const Positioned(
              left: -8,
              top: -8,
              child: Geometry(
                  shape: GeometryShape.hatch,
                  size: 96,
                  tone: GeometryTone.onPanel),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox.expand(child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.hint,
    required this.shortcut,
    required this.onPressed,
  });

  final CardRating rating;
  final String hint;
  final int shortcut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final again = rating == CardRating.again;
    final good = rating == CardRating.good;
    final ink = good ? t.onAction : (again ? t.danger : t.ink);
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(rating.label,
              style: theme.textTheme.labelLarge?.copyWith(color: ink)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(hint,
              style: theme.textTheme.bodySmall?.copyWith(color: ink)),
        ),
      ],
    );
    const padding =
        EdgeInsets.symmetric(horizontal: 2, vertical: AppSpacing.xs);
    const size = Size(0, 64);
    return Semantics(
      button: true,
      label: '${rating.label}, next review in $hint. Shortcut $shortcut.',
      excludeSemantics: true,
      onTap: onPressed,
      // Good is the filled default; Again is outlined in danger.
      child: good
          ? FilledButton(
              style: FilledButton.styleFrom(
                  padding: padding,
                  minimumSize: size,
                  foregroundColor: t.onAction),
              onPressed: onPressed,
              child: label,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: padding,
                minimumSize: size,
                foregroundColor: again ? t.danger : t.ink,
                side: BorderSide(
                    color: again ? t.danger : t.lineStrong, width: 1.5),
              ),
              onPressed: onPressed,
              child: label,
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
        child: StateMessage(
          kind: StateKind.empty,
          title: 'All caught up',
          message:
              'No cards are due right now. They come back when they are due.',
        ),
      );
}

class _Summary extends ConsumerWidget {
  const _Summary({
    super.key,
    required this.total,
    required this.recalled,
    required this.xp,
  });

  final int total;
  final int recalled;
  final int xp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reward = ref.read(appControllerProvider).lastReward;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SessionSummaryBadge(
                  title: 'Session complete',
                  line:
                      'You remembered $recalled of $total cards${xp > 0 ? ' and earned $xp XP' : ''}.',
                ),
                if (reward != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  RewardNews(reward: reward),
                ],
              ],
            ),
          ),
        ),
        PrimaryButton(
          label: 'Done',
          block: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// A trophy, a title and one line, shared by the simple summaries.
class SessionSummaryBadge extends StatelessWidget {
  const SessionSummaryBadge(
      {super.key, required this.title, required this.line});

  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Geometry(shape: GeometryShape.ring, size: 96),
              const Positioned(
                right: 6,
                top: 6,
                child: Geometry(shape: GeometryShape.disc, size: 28),
              ),
              Icon(Icons.check, size: 40, color: t.ink),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(line,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: t.inkMuted)),
      ],
    );
  }
}

/// Opens a flashcard session, or says why there is nothing to review.
void openFlashcards(BuildContext context, WidgetRef ref) {
  final cards = ref.read(appControllerProvider).flashcardSession();
  if (cards.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Nothing to review right now. Start a lesson to unlock new words.'),
    ));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => FlashcardSessionView(cards: cards),
  ));
}
