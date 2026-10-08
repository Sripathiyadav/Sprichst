import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/games/article_swipe.dart';
import '../../domain/games/game_models.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'article_chip.dart';
import 'game_page.dart';

/// Artikel-Rausch. Swipe the noun left for der, up for die, right for das, or
/// press the buttons: swiping is a shortcut, never the only way.
class ArticleSwipeView extends StatefulWidget {
  const ArticleSwipeView({
    super.key,
    required this.nouns,
    required this.onFinished,
    this.random,
  });

  final List<VocabItem> nouns;
  final void Function(GameOutcome outcome) onFinished;
  final math.Random? random;

  @override
  State<ArticleSwipeView> createState() => _ArticleSwipeViewState();
}

class _ArticleSwipeViewState extends State<ArticleSwipeView> {
  late final ArticleSwipeGame _game;
  Timer? _clock;
  Timer? _next;
  Offset _drag = Offset.zero;
  VocabItem? _answered;
  ({bool right, String article, String german})? _feedback;

  static const _swipeDistance = 70.0;

  @override
  void initState() {
    super.initState();
    _game = ArticleSwipeGame.draw(widget.nouns, widget.random ?? math.Random());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_feedback != null) return;
      setState(_game.tick);
      if (_game.isOver) _end();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _next?.cancel();
    super.dispose();
  }

  void _answer(String article) {
    if (_feedback != null || _game.isOver) return;
    final card = _game.current!;
    final right = _game.answer(article);
    setState(() {
      _answered = card;
      _drag = Offset.zero;
      _feedback = (right: right, article: card.article!, german: card.german);
    });
    _next = Timer(Duration(milliseconds: right ? 450 : 1300), () {
      if (!mounted) return;
      setState(() => _feedback = null);
      if (_game.isOver) _end();
    });
  }

  void _end() {
    _clock?.cancel();
    widget.onFinished(_game.finish());
  }

  void _dragEnd() {
    final d = _drag;
    if (d.distance < _swipeDistance) {
      setState(() => _drag = Offset.zero);
      return;
    }
    if (d.dx.abs() > d.dy.abs()) {
      _answer(d.dx < 0 ? 'der' : 'das');
    } else if (d.dy < 0) {
      _answer('die');
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedback = _feedback;
    final card = feedback == null ? _game.current : _answered;
    final seconds = _game.remaining.inSeconds.clamp(0, 999);
    final low = seconds <= 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameHud(
          score: _game.score,
          combo: _game.combo,
          trailing: Semantics(
            label: '$seconds seconds left',
            child: Chip(
              avatar: Icon(Icons.timer_outlined,
                  size: 18, color: low ? theme.colorScheme.error : null),
              label: Text('${seconds}s'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _game.answered / _game.total,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: context.accent,
          ),
        ),
        Expanded(
          child: Center(
            child: card == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    onPanUpdate: (d) => setState(() => _drag += d.delta),
                    onPanEnd: (_) => _dragEnd(),
                    child: AnimatedContainer(
                      duration: _drag == Offset.zero
                          ? motionDuration(context, 160)
                          : Duration.zero,
                      transform:
                          Matrix4.translationValues(_drag.dx, _drag.dy, 0)
                            ..rotateZ(_drag.dx / 900),
                      transformAlignment: Alignment.center,
                      child: _NounCard(noun: card, feedback: feedback),
                    ),
                  ),
          ),
        ),
        Text(
          feedback == null
              ? 'Swipe ← der · ↑ die · → das, or tap a button'
              : feedback.right
                  ? 'Richtig!'
                  : 'It is ${feedback.article} ${feedback.german}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final article in articles) ...[
              Expanded(
                child: _ArticleButton(
                  article: article,
                  onPressed: () => _answer(article),
                ),
              ),
              if (article != articles.last)
                const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      ],
    );
  }
}

class _NounCard extends StatelessWidget {
  const _NounCard({required this.noun, this.feedback});

  final VocabItem noun;
  final ({bool right, String article, String german})? feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = feedback;
    final color = result == null
        ? null
        : result.right
            ? context.successSurface
            : context.dangerSurface;
    final onColor = result == null
        ? null
        : result.right
            ? context.onSuccessSurface
            : context.onDangerSurface;
    return Semantics(
      label: 'Which article for ${noun.german}, meaning ${noun.english}?',
      child: SoftCard(
        color: color,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.xxl),
        child: SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result != null)
                ArticleChip(result.article, large: true)
              else
                const SizedBox(height: 44, child: Icon(Icons.help_outline)),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(noun.german,
                    style: theme.textTheme.displayMedium
                        ?.copyWith(color: onColor)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(noun.english,
                  style: theme.textTheme.titleMedium?.copyWith(color: onColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleButton extends StatelessWidget {
  const _ArticleButton({required this.article, required this.onPressed});

  final String article;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ArticleColors.of(article, Theme.of(context).brightness);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        minimumSize: const Size(64, 64),
      ),
      onPressed: onPressed,
      child: Text(article,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: colors.foreground)),
    );
  }
}
