import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The decorative shapes of the design system: a coral disc, a hairline ring, a
/// quarter arc, a half disc and the zigzag hatch.
enum GeometryShape { disc, ring, arc, half, hatch }

/// Which colour a shape takes. [coral] is the brand fill; [tint] a pale coral;
/// [ink] a neutral (a charcoal disc, an ink ring); [onPanel] a hatch or ring
/// drawn on a charcoal panel.
enum GeometryTone { coral, tint, ink, onPanel }

/// One decorative shape. It is decoration only: hidden from assistive
/// technology, carries no information, never animates, and should sit behind
/// headings and numbers, never under lesson text, answers, inputs or chat. Use
/// at most one disc, one ring and one hatch per screen, bleeding off an edge.
class Geometry extends StatelessWidget {
  const Geometry({
    super.key,
    required this.shape,
    this.size = 80,
    this.tone = GeometryTone.coral,
  });

  final GeometryShape shape;
  final double size;
  final GeometryTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch ((shape, tone)) {
      (GeometryShape.hatch, GeometryTone.onPanel) => t.lineOnPanel,
      (GeometryShape.hatch, _) => t.line,
      (GeometryShape.ring, GeometryTone.onPanel) => t.lineOnPanel,
      (GeometryShape.ring, _) => t.lineStrong,
      (_, GeometryTone.tint) => t.coralTint,
      (_, GeometryTone.ink) => t.panel,
      (_, GeometryTone.onPanel) => t.lineOnPanel,
      _ => t.coral,
    };
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: GeometryPainter(shape, color),
        ),
      ),
    );
  }
}

class GeometryPainter extends CustomPainter {
  const GeometryPainter(this.shape, this.color);

  final GeometryShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    switch (shape) {
      case GeometryShape.disc:
        canvas.drawCircle(size.center(Offset.zero), size.width / 2, fill);
      case GeometryShape.ring:
        canvas.drawCircle(
          size.center(Offset.zero),
          size.width / 2 - .5,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case GeometryShape.arc:
        // A quarter disc whose corner sits at the bottom-left.
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, size.height), radius: size.width),
          -math.pi / 2,
          math.pi / 2,
          true,
          fill,
        );
      case GeometryShape.half:
        canvas.drawArc(
          Rect.fromCircle(
              center: Offset(size.width / 2, size.height),
              radius: size.width / 2),
          math.pi,
          math.pi,
          true,
          fill,
        );
      case GeometryShape.hatch:
        final line = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round;
        const step = 8.0;
        for (var y = step; y < size.height + step; y += step) {
          final path = Path()..moveTo(0, y);
          var up = true;
          for (var x = step; x <= size.width + step; x += step) {
            path.lineTo(x, up ? y - step / 2 : y);
            up = !up;
          }
          canvas.drawPath(path, line);
        }
    }
  }

  @override
  bool shouldRepaint(GeometryPainter old) =>
      old.shape != shape || old.color != color;
}
