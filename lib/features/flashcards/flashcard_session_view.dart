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
        appBar: AppBar(title: const Text('Flashcards')),
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
                            ? const Center(child: CircularProgressIndicator())
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
    return Column(
      key: ValueKey('card$_index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('${_index + 1} / ${_queue.length}',
              style: theme.textTheme.titleMedium),
          const Spacer(),
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(card.isNew ? 'New word' : 'Review'),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _index / _queue.length,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: context.accent,
          ),
        ),
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
              child: SoftCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        toGerman ? 'In German:' : 'What does it mean?',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          toGerman ? item.english : item.german,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayMedium,
                        ),
                      ),
                      if (!_revealed && item.isNoun && !toGerman) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text('Which article?',
                            style: theme.textTheme.bodyMedium),
                      ],
                      if (_revealed) ...[
                        const Divider(height: AppSpacing.xxl),
                        if (item.article != null)
                          ArticleChip(item.article!, large: true),
                        if (item.article != null)
                          const SizedBox(height: AppSpacing.xs),
                        Text(
                          toGerman ? item.display : item.english,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        if (item.example != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(item.example!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium),
                          if (item.exampleEnglish != null)
                            Text(item.exampleEnglish!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        SpeakButton(
                          text: item.example ?? item.display,
                          label: 'Listen',
                          filled: true,
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xl),
                          child: Text('Tap the card or press Space',
                              style: theme.textTheme.bodyMedium),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_revealed)
          FilledButton(onPressed: _reveal, child: const Text('Show answer'))
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
                const SizedBox(width: AppSpacing.xxs),
            ],
          ]),
      ],
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
    final scheme = theme.colorScheme;
    final (background, foreground) = switch (rating) {
      CardRating.again => (context.dangerSurface, context.onDangerSurface),
      CardRating.hard => (scheme.surfaceContainerHigh, scheme.onSurface),
      CardRating.good => (context.successSurface, context.onSuccessSurface),
      CardRating.easy => (scheme.primary, scheme.onPrimary),
    };
    return Semantics(
      button: true,
      label: '${rating.label}, next review in $hint. Shortcut $shortcut.',
      excludeSemantics: true,
      onTap: onPressed,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(
              horizontal: 2, vertical: AppSpacing.xs),
          minimumSize: const Size(0, 64),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(rating.label,
                  style:
                      theme.textTheme.titleMedium?.copyWith(color: foreground)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(hint,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text('All caught up',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text('No cards are due right now.'),
          ],
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
                  title: 'Session complete!',
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
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        CircleAvatar(
          radius: 38,
          backgroundColor: scheme.tertiary,
          foregroundColor: scheme.onTertiary,
          child: const Icon(Icons.emoji_events, size: 38),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(line, textAlign: TextAlign.center),
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
