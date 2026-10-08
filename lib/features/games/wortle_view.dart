import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/games/game_models.dart';
import '../../domain/games/wortle.dart';
import '../../shared/widgets/app_widgets.dart';

/// Wortle: six tries to find the five-letter word. A correct letter is filled
/// gold, a misplaced letter has a gold ring, an absent one is grey — shape as
/// well as colour, and every cell is announced to screen readers.
class WortleView extends StatefulWidget {
  const WortleView({super.key, required this.answer, required this.onFinished});

  final String answer;
  final void Function(GameOutcome outcome) onFinished;

  @override
  State<WortleView> createState() => _WortleViewState();
}

class _WortleViewState extends State<WortleView> {
  late final WortleGame _game = WortleGame(widget.answer);
  final _focus = FocusNode();
  final _field = TextEditingController();
  var _typed = '';
  String? _message;

  static const _rows = ['QWERTZUIOP', 'ASDFGHJKL', 'YXCVBNM'];

  @override
  void dispose() {
    _focus.dispose();
    _field.dispose();
    super.dispose();
  }

  void _letter(String letter) {
    if (_game.isOver || _typed.length >= WortleGame.wordLength) return;
    setState(() {
      _message = null;
      _typed += letter;
    });
  }

  void _back() {
    if (_typed.isEmpty) return;
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  void _enter() {
    if (_game.isOver) return;
    if (_typed.length < WortleGame.wordLength) {
      setState(() => _message = 'Five letters, please.');
      return;
    }
    final result = _game.submit(_typed);
    _field.clear();
    setState(() {
      _typed = '';
      _message = result == null ? 'Letters only, please.' : null;
      if (_game.isLost) _message = 'The word was ${_game.answer}.';
    });
    if (_game.isOver) {
      Future<void>.delayed(
        Duration(milliseconds: _game.isWon ? 900 : 2200),
        () {
          if (mounted) widget.onFinished(_game.finish());
        },
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter) {
      _enter();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _back();
      return KeyEventResult.handled;
    }
    final char = event.character?.toUpperCase();
    if (char != null && RegExp(r'^[A-ZÄÖÜ]$').hasMatch(char)) {
      _letter(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = _game.keyboard;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Guess the five-letter German word.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 5 / 6,
                child: Column(
                  children: [
                    for (var row = 0; row < WortleGame.maxGuesses; row++)
                      Expanded(child: _row(row)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: Text(_message ?? '', style: theme.textTheme.bodyMedium),
              ),
            ),
          ),
          if (MediaQuery.accessibleNavigationOf(context))
            _screenReaderInput(theme)
          else ...[
            for (final letters in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final l in letters.split(''))
                      _Key(
                          label: l, mark: keyboard[l], onTap: () => _letter(l)),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Key(
                    label: 'Enter',
                    wide: true,
                    onTap: _enter,
                    semantic: 'Submit guess'),
                for (final l in const ['Ä', 'Ö', 'Ü'])
                  _Key(label: l, mark: keyboard[l], onTap: () => _letter(l)),
                _Key(
                    label: '⌫',
                    wide: true,
                    onTap: _back,
                    semantic: 'Delete last letter'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// With a screen reader on, the small on-screen keys are replaced by a text
  /// field: the platform keyboard is the accessible way to type, and every key
  /// there already meets the target size.
  Widget _screenReaderInput(ThemeData theme) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _field,
              maxLength: WortleGame.wordLength,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÄÖÜäöü]')),
              ],
              decoration: const InputDecoration(labelText: 'Your guess'),
              onChanged: (v) => setState(() => _typed = v.toUpperCase()),
              onSubmitted: (_) => _enter(),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton(
              onPressed: _enter,
              child: const Text('Submit guess'),
            ),
          ),
        ],
      );

  Widget _row(int row) {
    final submitted = row < _game.guesses.length;
    final current = row == _game.guesses.length && !_game.isOver;
    return Row(
      children: [
        for (var col = 0; col < WortleGame.wordLength; col++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: _Cell(
                letter: submitted
                    ? _game.guesses[row][col]
                    : current && col < _typed.length
                        ? _typed[col]
                        : '',
                mark: submitted ? _game.marks[row][col] : null,
                active: current && col == _typed.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.letter, this.mark, this.active = false});

  final String letter;
  final LetterMark? mark;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground, border, radius) = switch (mark) {
      LetterMark.correct => (
          context.successSurface,
          context.onSuccessSurface,
          scheme.tertiary,
          10.0,
        ),
      LetterMark.present => (
          Colors.transparent,
          scheme.onSurface,
          scheme.tertiary,
          99.0,
        ),
      LetterMark.absent => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Colors.transparent,
          10.0,
        ),
      null => (
          Colors.transparent,
          scheme.onSurface,
          active ? scheme.onSurface : scheme.outlineVariant,
          10.0,
        ),
    };
    final meaning = switch (mark) {
      LetterMark.correct => 'correct place',
      LetterMark.present => 'wrong place',
      LetterMark.absent => 'not in word',
      null => letter.isEmpty ? 'empty' : 'typed',
    };
    return Semantics(
      label: letter.isEmpty ? 'Empty' : '$letter, $meaning',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: motionDuration(context, 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
              color: border, width: mark == LetterMark.present ? 3 : 2),
        ),
        child: Text(letter,
            style: theme.textTheme.headlineMedium?.copyWith(color: foreground)),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    this.mark,
    this.wide = false,
    this.semantic,
  });

  final String label;
  final LetterMark? mark;
  final bool wide;
  final String? semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (mark) {
      LetterMark.correct => context.successSurface,
      LetterMark.present => scheme.surfaceContainerHigh,
      LetterMark.absent => scheme.surfaceContainerHighest.withValues(alpha: .5),
      null => scheme.surfaceContainerHigh,
    };
    final foreground = switch (mark) {
      LetterMark.correct => context.onSuccessSurface,
      LetterMark.absent => scheme.outline,
      _ => scheme.onSurface,
    };
    return Expanded(
        flex: wide ? 3 : 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Semantics(
            button: true,
            label: semantic ?? label,
            excludeSemantics: true,
            onTap: onTap,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(8),
                  border: mark == LetterMark.present
                      ? Border.all(color: scheme.tertiary, width: 2)
                      : null,
                ),
                child: Text(label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foreground, fontSize: wide ? 13 : 16)),
              ),
            ),
          ),
        ));
  }
}
