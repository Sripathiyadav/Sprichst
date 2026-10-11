import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/games/game_models.dart';
import '../../domain/games/word_scramble.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'game_page.dart';

/// Buchstabensalat: build the word by tapping its letters in order.
class WordScrambleView extends StatefulWidget {
  const WordScrambleView({
    super.key,
    required this.words,
    required this.onFinished,
    this.random,
  });

  final List<VocabItem> words;
  final void Function(GameOutcome outcome) onFinished;
  final math.Random? random;

  @override
  State<WordScrambleView> createState() => _WordScrambleViewState();
}

class _WordScrambleViewState extends State<WordScrambleView> {
  late final WordScrambleGame _game;

  /// Indexes into the round's letters, in the order they were tapped.
  final List<int> _picked = [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _game = WordScrambleGame(widget.words, widget.random ?? math.Random());
    if (_game.rounds.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onFinished(_game.finish()));
    }
  }

  String _text(ScrambleRound round) =>
      _picked.map((i) => round.letters[i]).join();

  void _tap(int index) {
    final round = _game.current!;
    if (_picked.contains(index)) return;
    setState(() {
      _message = null;
      _picked.add(index);
    });
    if (_picked.length == round.letters.length) _check(round);
  }

  void _check(ScrambleRound round) {
    final ok = _game.guess(_text(round));
    setState(() {
      _picked.clear();
      _message = ok ? 'Richtig!' : 'Not quite — try again.';
    });
    if (ok && _game.isOver) widget.onFinished(_game.finish());
  }

  void _skip() {
    final round = _game.current!;
    setState(() {
      _picked.clear();
      _message = 'It was ${round.word.display}.';
    });
    _game.skip();
    if (_game.isOver) widget.onFinished(_game.finish());
  }

  @override
  Widget build(BuildContext context) {
    final round = _game.current;
    if (round == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final text = _text(round);
    final hint = _game.hintText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameHud(
          score: _game.score,
          combo: _game.combo,
          trailing: Text('Word ${_game.index + 1} / ${_game.rounds.length}'),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Unscramble the German word for',
            style: theme.textTheme.bodyMedium),
        Text('"${round.word.english}"', style: theme.textTheme.headlineMedium),
        if (round.word.article != null)
          Text('Article: ${round.word.article}',
              style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        SoftCard(
          child: SizedBox(
            height: 56,
            child: Center(
              child: Semantics(
                liveRegion: true,
                label: text.isEmpty
                    ? 'Your answer is empty'
                    : 'Your answer: $text',
                excludeSemantics: true,
                child: Text(
                  text.isEmpty ? (hint.isEmpty ? '' : hint) : text,
                  style: theme.textTheme.displaySmall?.copyWith(
                    letterSpacing: 4,
                    color: text.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: Text(_message ?? '', style: theme.textTheme.bodyMedium),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < round.letters.length; i++)
              _LetterKey(
                letter: round.letters[i],
                used: _picked.contains(i),
                onTap: () => _tap(i),
              ),
          ],
        ),
        const Spacer(),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _picked.isEmpty
                  ? null
                  : () => setState(() => _picked.removeLast()),
              icon: const Icon(Icons.backspace_outlined),
              label: const Text('Undo'),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(_game.hint),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Hint'),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextButton(onPressed: _skip, child: const Text('Skip')),
          ),
        ]),
      ],
    );
  }
}

class _LetterKey extends StatelessWidget {
  const _LetterKey(
      {required this.letter, required this.used, required this.onTap});

  final String letter;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: !used,
      label: letter,
      excludeSemantics: true,
      onTap: used ? null : onTap,
      child: GestureDetector(
        onTap: used ? null : onTap,
        child: AnimatedContainer(
          duration: motionDuration(context, 150),
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: used ? scheme.surfaceContainerHighest : scheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Text(
            letter.toUpperCase(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: used ? scheme.outline : scheme.onPrimary,
                ),
          ),
        ),
      ),
    );
  }
}
