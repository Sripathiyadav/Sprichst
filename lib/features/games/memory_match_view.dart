import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/games/game_models.dart';
import '../../domain/games/memory_match.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

/// Memory: find each German word's English meaning.
class MemoryMatchView extends StatefulWidget {
  const MemoryMatchView({
    super.key,
    required this.words,
    required this.onFinished,
    this.random,
  });

  final List<VocabItem> words;
  final void Function(GameOutcome outcome) onFinished;
  final math.Random? random;

  @override
  State<MemoryMatchView> createState() => _MemoryMatchViewState();
}

class _MemoryMatchViewState extends State<MemoryMatchView> {
  late final MemoryMatchGame _game;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _game = MemoryMatchGame(widget.words, widget.random ?? math.Random());
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _flip(int i) {
    final result = _game.flip(i);
    setState(() {});
    if (result == false) {
      _hide = Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(_game.hideMismatch);
      });
    } else if (_game.isOver) {
      _hide = Timer(const Duration(milliseconds: 700), () {
        if (mounted) widget.onFinished(_game.finish());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matched =
        _game.tiles.indexed.where((e) => _game.isMatched(e.$1)).length ~/ 2;
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 560 ? 4 : 3;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('Pairs $matched / ${_game.pairs}',
                style: theme.textTheme.titleLarge),
            const Spacer(),
            Text('${_game.moves} moves', style: theme.textTheme.bodyMedium),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text('Match each German word with its meaning.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
                childAspectRatio: 1.25,
              ),
              itemCount: _game.tiles.length,
              itemBuilder: (context, i) => _Tile(
                tile: _game.tiles[i],
                shown: _game.isShown(i),
                matched: _game.isMatched(i),
                onTap: () => _flip(i),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tile,
    required this.shown,
    required this.matched,
    required this.onTap,
  });

  final MemoryTile tile;
  final bool shown;
  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = matched
        ? context.successSurface
        : shown
            ? scheme.surfaceContainerHighest
            : scheme.primary;
    final foreground = matched
        ? context.onSuccessSurface
        : shown
            ? scheme.onSurface
            : scheme.onPrimary;
    return Semantics(
      button: !shown,
      label: shown
          ? '${tile.isGerman ? 'German' : 'English'}: ${tile.label}${matched ? ', matched' : ''}'
          : 'Face-down card',
      excludeSemantics: true,
      onTap: shown ? null : onTap,
      child: PressableTile(
        onTap: shown ? null : onTap,
        child: AnimatedContainer(
          duration: motionDuration(context, 220),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.control + 2),
            border: Border.all(
                color: shown ? scheme.outline : Colors.transparent, width: 1.5),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: shown
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tile.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight:
                          tile.isGerman ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                )
              : Icon(Icons.help_outline_rounded, color: foreground, size: 30),
        ),
      ),
    );
  }
}

/// A tappable tile with no ink, used where the tile is its own feedback.
class PressableTile extends StatelessWidget {
  const PressableTile({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
      behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
}
