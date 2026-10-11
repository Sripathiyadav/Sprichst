import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// A surface that is either a plain card (standard) or Liquid Glass.
///
/// Glass here means four things working together: a translucent tinted fill, a
/// bright specular edge that catches light from the top-left, a soft floating
/// shadow, and (when [blur] is set) a blur of whatever is behind it. Blur is
/// reserved for surfaces that content scrolls under, like the floating
/// navigation; ordinary cards sit on the ambient background, where blur would
/// change nothing and cost a lot of scrolling performance.
/// How far a glass surface appears to float above the page.
enum GlassDepth {
  /// Ordinary cards: a tight shadow that stays inside the page margin, so
  /// neighbouring cards do not smear into bands or get clipped by a list.
  card,

  /// Navigation that hovers over scrolling content.
  floating,
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.card,
    this.blur = false,
    this.padding,
    this.tint,
  }) : depth = blur ? GlassDepth.floating : GlassDepth.card;

  final Widget child;
  final double radius;
  final bool blur;
  final EdgeInsetsGeometry? padding;

  /// Replaces the default surface colour as the glass tint.
  final Color? tint;

  /// Floating surfaces (the ones that blur) cast the deeper shadow.
  final GlassDepth depth;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    // Its own transparent Material, so ink splashes and ripples inside the card
    // paint above the card's fill instead of underneath it.
    final padded = Material(
      type: MaterialType.transparency,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    if (!glass.enabled) {
      final flat = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: scheme.outlineVariant),
      );
      return DecoratedBox(
        decoration: ShapeDecoration(color: tint ?? scheme.surface, shape: flat),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: flat),
          child: padded,
        ),
      );
    }

    final isDark = scheme.brightness == Brightness.dark;
    // A bright wash at the top fading to the plain fill gives the glass its
    // sense of thickness; it is subtler on light surfaces, which are already
    // bright.
    final fill = glass.fill(scheme, tint: tint);
    final topFill = glass.topFill(scheme, tint: tint);

    Widget surface = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topFill, fill],
          stops: const [0, .6],
        ),
      ),
      child: padded,
    );

    if (blur) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: glass.blurSigma,
          sigmaY: glass.blurSigma,
          tileMode: TileMode.mirror,
        ),
        child: surface,
      );
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: [
          if (depth == GlassDepth.floating)
            BoxShadow(
              color: Colors.black.withValues(alpha: glass.shadow),
              blurRadius: 28,
              offset: const Offset(0, 10),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: glass.shadow * .6),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _SpecularEdgePainter(
          shape: shape,
          highlight: Colors.white.withValues(alpha: glass.specular),
          hairline: scheme.outlineVariant.withValues(alpha: isDark ? .9 : .7),
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: surface,
        ),
      ),
    );
  }
}

/// Draws the glass rim: a hairline for definition on any backdrop, and above it
/// a gradient highlight that is brightest at the top-left and bottom-right
/// corners and absent along the sides, the way light catches a bevelled edge.
class _SpecularEdgePainter extends CustomPainter {
  const _SpecularEdgePainter({
    required this.shape,
    required this.highlight,
    required this.hairline,
  });

  final ShapeBorder shape;
  final Color highlight;
  final Color hairline;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(
      shape.getOuterPath(rect.deflate(.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = hairline,
    );
    canvas.drawPath(
      shape.getOuterPath(rect.deflate(1.6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            highlight,
            highlight.withValues(alpha: 0),
            highlight.withValues(alpha: 0),
            highlight.withValues(alpha: highlight.a * .45),
          ],
          stops: const [0, .35, .65, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpecularEdgePainter old) =>
      old.highlight != highlight ||
      old.hairline != hairline ||
      old.shape != shape;
}

/// The soft red and gold light that sits behind the app, giving Liquid Glass
/// something to pick up. With standard surfaces it is just the page colour.
///
/// It paints an opaque base itself, so routes that use it never show the page
/// beneath them while they animate.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final theme = Theme.of(context);
    final base = theme.scaffoldBackgroundColor;
    if (!glass.enabled) return ColoredBox(color: base, child: child);

    final isDark = theme.brightness == Brightness.dark;
    final palette = SprichstPalette.flag;
    final red = Color(palette.red.get(isDark ? 38 : 80));
    final gold = Color(palette.gold.get(isDark ? 42 : 86));
    final strength = glass.ambientStrength;

    Widget glow(Color color, Alignment center, double radius, double alpha) =>
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: center,
                radius: radius,
                colors: [
                  color.withValues(alpha: alpha * strength),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );

    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Static light: isolate it so scrolling never repaints it.
          RepaintBoundary(
            child: IgnorePointer(
              child: Stack(
                children: [
                  glow(red, const Alignment(1.15, -1.0), 1.0, .55),
                  glow(gold, const Alignment(-1.2, .55), 1.05, .50),
                  glow(red, const Alignment(.9, 1.25), .8, .30),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
