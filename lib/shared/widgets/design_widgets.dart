import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import 'geometry.dart';

/// Duration for [AppMotion.quick], [AppMotion.standard] and
/// [AppMotion.emphasis] that respects the system's reduce-motion setting.
abstract final class AppMotion {
  static Duration quick(BuildContext context) => _d(context, 120);
  static Duration standard(BuildContext context) => _d(context, 200);
  static Duration emphasis(BuildContext context) => _d(context, 320);
  static const curve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  static Duration _d(BuildContext context, int ms) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: ms);
}

/// The oversized number that headlines a screen, optionally on the coral disc
/// with an outline ring at its lower right.
///
/// Use one hero number per screen, and only for a number that matters to the
/// learner today. Single digits get a leading zero ("07"). The value must be
/// real data: show a [StateMessage] instead of a zero you cannot vouch for.
class EditorialNumber extends StatelessWidget {
  const EditorialNumber({
    super.key,
    required this.value,
    this.label,
    this.unit,
    this.caption,
    this.size = EditorialSize.hero,
    this.disc = false,
  });

  final int value;

  /// Above the number, in capitals ("DAY STREAK").
  final String? label;

  /// After the number ("days").
  final String? unit;
  final String? caption;
  final EditorialSize size;

  /// Draw the coral disc behind the number.
  final bool disc;

  String get _digits => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final style = switch (size) {
      EditorialSize.hero => theme.textTheme.displayLarge,
      EditorialSize.numeral => theme.textTheme.displayMedium,
      EditorialSize.stat => theme.textTheme.headlineLarge,
    }!;
    final number = Text(_digits, style: style);
    final spoken = [
      '$value',
      if (unit != null) unit!,
      if (label != null) label!.toLowerCase(),
    ].join(' ');

    Widget numberBlock = number;
    if (disc) {
      // The number sits on the disc; the ring overlaps the disc's lower right.
      // Nothing bleeds past the block, so a scrolling list never clips it.
      final d = (style.fontSize ?? 120) * 1.4;
      numberBlock = SizedBox(
        width: d * 1.35,
        height: d * 1.05,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
                left: 0,
                top: 0,
                child: Geometry(shape: GeometryShape.disc, size: d)),
            Positioned(
                left: d * .72,
                top: d * .5,
                child: Geometry(shape: GeometryShape.ring, size: d * .55)),
            Positioned(
              left: 0,
              top: 0,
              width: d,
              height: d,
              child: Center(child: number),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(label!.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: t.accent)),
            ),
          numberBlock,
          if (unit != null || caption != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                [if (unit != null) unit!, if (caption != null) caption!]
                    .join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(color: t.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

enum EditorialSize { hero, numeral, stat }

/// The charcoal editorial panel: the one featured item on a screen (continue
/// learning, the lesson body, the flashcard). Use one per screen; two compete.
/// The action is a labelled coral arrow, never a bare arrow.
class FeaturePanel extends StatelessWidget {
  const FeaturePanel({
    super.key,
    required this.title,
    this.eyebrow,
    this.children = const [],
    this.meta,
    this.actionLabel,
    this.onAction,
    this.tools,
    this.hatch = true,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> children;
  final String? meta;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Icon buttons in a rule at the top (listen, text size).
  final List<Widget>? tools;
  final bool hatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final shape = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel));
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.panel,
        shape: shape,
        shadows: t.brightness == Brightness.light
            ? const [
                BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 4)),
                BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 36,
                    spreadRadius: -12,
                    offset: Offset(0, 18)),
              ]
            : const [
                BoxShadow(
                    color: Color(0xB3000000),
                    blurRadius: 36,
                    spreadRadius: -12,
                    offset: Offset(0, 18)),
              ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Stack(
          children: [
            if (hatch)
              const Positioned(
                left: -8,
                top: -8,
                child: Geometry(
                    shape: GeometryShape.hatch,
                    size: 96,
                    tone: GeometryTone.onPanel),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tools != null) ...[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: tools!),
                    Container(height: 1, color: t.lineOnPanel),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (eyebrow != null) ...[
                    Text(eyebrow!.toUpperCase(),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: t.accentOnPanel)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Semantics(
                    header: true,
                    child: Text(title,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: t.onPanel)),
                  ),
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    DefaultTextStyle.merge(
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: t.onPanelMuted),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    ),
                  ],
                  if (meta != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(meta!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: t.onPanelMuted)),
                  ],
                  if (actionLabel != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    PanelAction(label: actionLabel!, onPressed: onAction),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The labelled coral arrow that ends a [FeaturePanel].
class PanelAction extends StatelessWidget {
  const PanelAction({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: t.accentOnPanel,
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label)),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.arrow_forward, size: 22),
        ],
      ),
    );
  }
}

/// A button for the one next step on a screen. Charcoal with a coral arrow in
/// light mode, coral with a dark arrow in dark mode.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.arrow = true,
    this.icon,
    this.block = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool arrow;
  final IconData? icon;
  final bool block;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final button = FilledButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (arrow) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.arrow_forward,
                size: 22,
                color: onPressed == null ? t.inkMuted : t.actionGlyph),
          ],
        ],
      ),
    );
    return block ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A small label for status, category or provider, with an optional icon.
/// Status chips always pair an icon with a word.
class DsChip extends StatelessWidget {
  const DsChip(this.label,
      {super.key, this.icon, this.tone = ChipTone.outline});

  final String label;
  final IconData? icon;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final (bg, fg, border) = switch (tone) {
      ChipTone.neutral => (t.surfaceSunken, t.ink, null),
      ChipTone.outline => (null, t.ink, t.lineStrong),
      ChipTone.accent => (t.accentSoft, t.ink, null),
      ChipTone.success => (t.successSoft, t.success, null),
      ChipTone.warning => (t.warningSoft, t.warning, null),
      ChipTone.danger => (t.dangerSoft, t.danger, null),
      ChipTone.panel => (t.panel, t.onPanel, null),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: bg,
        shape: StadiumBorder(
            side: border == null
                ? BorderSide.none
                : BorderSide(color: border, width: 1)),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  style: theme.textTheme.labelMedium?.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

enum ChipTone { neutral, outline, accent, success, warning, danger, panel }

/// The learner's CEFR level in a hairline ring with a coral arc.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.caption});

  final CefrLevel level;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final short = switch (level) {
      CefrLevel.preA1 => 'A0',
      _ => level.label,
    };
    return Semantics(
      label: 'Level ${level.label}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Geometry(shape: GeometryShape.ring, size: 48),
                const Positioned(
                  left: 0,
                  bottom: 0,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      widthFactor: .5,
                      heightFactor: .5,
                      child: Geometry(
                          shape: GeometryShape.disc,
                          size: 48,
                          tone: GeometryTone.tint),
                    ),
                  ),
                ),
                Text(short,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(caption!, style: theme.textTheme.bodyMedium)),
          ],
        ],
      ),
    );
  }
}

enum StateKind { empty, error, offline, loading }

/// A whole region's state: loading, empty, error or offline. A hairline ring
/// with a coral disc and an icon, a title, a sentence and one action.
///
/// Empty states invite the next step; errors say what happened, what still
/// works and what to do; loading uses words as well as the arc, and the arc
/// stops under reduced motion.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final StateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _icon => switch (kind) {
        StateKind.empty => Icons.auto_stories_outlined,
        StateKind.error => Icons.error_outline,
        StateKind.offline => Icons.cloud_off,
        StateKind.loading => Icons.hourglass_empty,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      liveRegion: kind == StateKind.error || kind == StateKind.loading,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      child: Geometry(
                          shape: GeometryShape.disc,
                          size: 28,
                          tone: GeometryTone.coral)),
                  if (kind == StateKind.loading)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        // Under reduced motion the arc stays still; the words
                        // beside it say what is happening.
                        value: still ? .3 : null,
                        strokeWidth: 3,
                        color: t.accent,
                        backgroundColor: t.surfaceSunken,
                      ),
                    )
                  else
                    Icon(_icon, size: 32, color: t.ink),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: t.inkMuted)),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              kind == StateKind.empty
                  ? PrimaryButton(label: actionLabel!, onPressed: onAction)
                  : OutlinedButton(
                      onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One day of [WeekActivity].
class DayMinutes {
  const DayMinutes(this.label, this.minutes, {this.today = false});
  final String label;
  final int minutes;
  final bool today;
}

/// Minutes learned on each day of the week as bars, with today in coral and a
/// dashed line at the daily goal. Carries an accessible summary, so the chart
/// is never the only source of the numbers.
class WeekActivity extends StatelessWidget {
  const WeekActivity({super.key, required this.days, required this.goal});

  final List<DayMinutes> days;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final peak = days.fold<int>(goal, (m, d) => d.minutes > m ? d.minutes : m);
    const chart = 96.0;
    final summary = days
        .map((d) =>
            '${d.label} ${d.minutes == 0 ? 'no activity' : '${d.minutes} min'}')
        .join(', ');
    return Semantics(
      label: 'This week: $summary. Goal $goal minutes a day.',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: chart,
            child: CustomPaint(
              painter:
                  _GoalLinePainter(color: t.lineStrong, fraction: goal / peak),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Center(
                        child: d.minutes == 0
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: t.line, shape: BoxShape.circle),
                              )
                            : Container(
                                width: 18,
                                height: (chart * d.minutes / peak)
                                    .clamp(6.0, chart),
                                decoration: BoxDecoration(
                                  color: d.today ? t.coral : t.mark,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Text(d.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: d.today ? t.ink : t.inkMuted,
                          fontWeight:
                              d.today ? FontWeight.w700 : FontWeight.w500)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalLinePainter extends CustomPainter {
  const _GoalLinePainter({required this.color, required this.fraction});

  final Color color;
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (1 - fraction);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GoalLinePainter old) =>
      old.color != color || old.fraction != fraction;
}

/// The orbit mark, in the light or dark version to suit the theme. It is part
/// of the logo lockup (icon above the wordmark) on the opening screen and in
/// About; the launcher icon never carries the name. Not drawn below 24px.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Sprichst',
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .2237),
        child: Image.asset(
          dark
              ? 'assets/brand/sprichst-orbit-dark.png'
              : 'assets/brand/sprichst-orbit-light.png',
          width: size < 24 ? 24 : size,
          height: size < 24 ? 24 : size,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
