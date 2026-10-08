import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/games/dialogue_game.dart';
import '../../domain/games/game_models.dart';
import '../../domain/models/dialogue_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'game_page.dart';

/// Gespräch: a conversation where the learner chooses their own lines.
class DialogueGameView extends StatefulWidget {
  const DialogueGameView({
    super.key,
    required this.dialogue,
    required this.onFinished,
    this.random,
  });

  final Dialogue dialogue;
  final void Function(GameOutcome outcome) onFinished;
  final math.Random? random;

  @override
  State<DialogueGameView> createState() => _DialogueGameViewState();
}

class _DialogueGameViewState extends State<DialogueGameView> {
  late final DialogueGame _game;
  final _scroll = ScrollController();
  String? _verdict;
  Timer? _end;

  @override
  void initState() {
    super.initState();
    _game = DialogueGame(widget.dialogue, widget.random ?? math.Random())
      ..advance();
  }

  @override
  void dispose() {
    _end?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _reply(String option) {
    final turn = _game.pending!;
    final right = _game.reply(option);
    _game.advance();
    setState(() => _verdict = right ? null : 'Better: ${turn.answer}');
    _toBottom();
    if (_game.isOver) {
      _end = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) widget.onFinished(_game.finish());
      });
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: motionDuration(context, 250),
          curve: Curves.easeOut,
        );
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = _game.pending;
    final turns = _game.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameHud(score: _game.score, combo: _game.combo),
        const SizedBox(height: AppSpacing.xs),
        Text(widget.dialogue.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            itemCount: turns.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, i) {
              final turn = turns[i];
              if (!turn.isLearner) {
                return _Bubble(text: turn.text, gloss: turn.english);
              }
              final chosen = _game.chosenAt(i);
              if (chosen == null) {
                return _Bubble(text: '…', mine: true, hint: turn.intent);
              }
              return _Bubble(
                text: turn.answer!,
                mine: true,
                correct: chosen == turn.answer,
              );
            },
          ),
        ),
        if (_verdict != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Semantics(
              liveRegion: true,
              child: Text(_verdict!, style: theme.textTheme.bodyMedium),
            ),
          ),
        if (pending != null) ...[
          Text('Your reply: ${pending.intent}',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final option in _game.options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
                onPressed: () => _reply(option),
                child: Text(option, textAlign: TextAlign.start),
              ),
            ),
        ] else if (_game.isOver)
          const Center(child: Text('Konversation beendet!')),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    this.gloss,
    this.hint,
    this.mine = false,
    this.correct,
  });

  final String text;
  final String? gloss;
  final String? hint;
  final bool mine;
  final bool? correct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = mine
        ? (correct == false ? context.dangerSurface : scheme.primaryContainer)
        : scheme.surfaceContainerHigh;
    final foreground = mine
        ? (correct == false
            ? context.onDangerSurface
            : scheme.onPrimaryContainer)
        : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .75),
        child: Semantics(
          label:
              '${mine ? 'You' : 'Partner'}: $text${correct == null ? '' : correct! ? ', correct' : ', not the best reply'}',
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(text,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: foreground)),
                      ),
                      if (correct != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                            correct!
                                ? Icons.check_circle
                                : Icons.cancel_outlined,
                            size: 18,
                            color: foreground),
                      ],
                    ],
                  ),
                  if (gloss != null)
                    Text(gloss!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground.withValues(alpha: .8))),
                  if (hint != null)
                    Text(hint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground.withValues(alpha: .8))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
