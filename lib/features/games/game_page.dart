import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/games/game_models.dart';
import '../../domain/learning/achievements.dart';
import '../../shared/widgets/app_widgets.dart';
import '../gamification/reward_news.dart';

typedef GameBuilder = Widget Function(
    BuildContext context, void Function(GameOutcome outcome) onFinished);

/// The frame every game shares: play, then a result screen that saves progress
/// and offers another round. A game only has to build its board and call
/// `onFinished` with its [GameOutcome].
class GamePage extends ConsumerStatefulWidget {
  const GamePage({super.key, required this.game, required this.builder});

  final GameId game;
  final GameBuilder builder;

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  var _round = 0;
  GameOutcome? _outcome;
  var _xp = 0;
  GamificationResult? _reward;

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    return GlassPage(
      appBar: MastheadBar(eyebrow: widget.game.title),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Breakpoints.lessonMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AnimatedSwitcher(
                duration: motionDuration(context),
                child: outcome == null
                    ? KeyedSubtree(
                        key: ValueKey('round$_round'),
                        child: widget.builder(context, _finish),
                      )
                    : GameResultView(
                        key: const ValueKey('result'),
                        outcome: outcome,
                        xp: _xp,
                        reward: _reward,
                        onAgain: () => setState(() {
                          _outcome = null;
                          _reward = null;
                          _round++;
                        }),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish(GameOutcome outcome) async {
    final app = ref.read(appControllerProvider);
    var xp = 0;
    try {
      xp = (await app.completeGame(outcome)).xpEarned;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('We could not save this game. Your score is shown below.'),
        ));
      }
    }
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _xp = xp;
      _reward = app.lastReward;
    });
  }
}

class GameResultView extends StatelessWidget {
  const GameResultView({
    super.key,
    required this.outcome,
    required this.xp,
    required this.onAgain,
    this.reward,
  });

  final GameOutcome outcome;
  final int xp;
  final GamificationResult? reward;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = switch (outcome.stars) {
      3 => 'Ausgezeichnet!',
      2 => 'Sehr gut!',
      1 => 'Gut gemacht!',
      _ => 'Weiter üben!',
    };
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                _Stars(count: outcome.stars),
                const SizedBox(height: AppSpacing.md),
                Text(headline,
                    style: theme.textTheme.displaySmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${outcome.score} points · ${outcome.correct} of ${outcome.total} right'
                  '${outcome.bestCombo >= 3 ? ' · best streak ${outcome.bestCombo}' : ''}'
                  '${xp > 0 ? ' · +$xp XP' : ''}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (reward != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  RewardNews(reward: reward!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Play again'),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to Practice'),
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$count of 3 stars',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Icon(
                i < count ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 56,
                color: i < count
                    ? context.accent
                    : Theme.of(context).colorScheme.outline,
              ),
          ],
        ),
      );
}

/// The running score and combo shown above a game board.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.score,
    this.combo,
    this.trailing,
  });

  final int score;
  final ComboMeter? combo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multiplier = combo?.multiplier ?? 1;
    return Row(
      children: [
        Semantics(
          liveRegion: true,
          label: 'Score $score',
          excludeSemantics: true,
          child: Text('$score', style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('pts', style: theme.textTheme.bodyMedium),
        if (multiplier > 1) ...[
          const SizedBox(width: AppSpacing.sm),
          Chip(
            avatar: const Icon(Icons.bolt_rounded, size: 18),
            label: Text('×${multiplier.toStringAsFixed(1)}'),
            visualDensity: VisualDensity.compact,
          ),
        ],
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}
