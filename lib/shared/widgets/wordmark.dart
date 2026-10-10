import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// "Sprichst" in Figtree 700 with the dot on the i as a coral disc. Drawn from
/// a dotless ı and a separate disc, so no image is needed and the mark follows
/// the theme.
/// The dotless i (U+0131) the wordmark's coral disc stands on.
final _dotlessI = String.fromCharCode(0x131);

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = TextStyle(
      fontFamily: SprichstTheme.fontFamily,
      fontFamilyFallback: SprichstTheme.fontFallback,
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: -size * .02,
      color: t.ink,
    );
    final dot = size * .19;
    return Semantics(
      label: 'Sprichst',
      excludeSemantics: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Spr', style: style, textScaler: TextScaler.noScaling),
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Text(_dotlessI, style: style, textScaler: TextScaler.noScaling),
                Padding(
                  padding: EdgeInsets.only(top: size * .1),
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration:
                        BoxDecoration(color: t.coral, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
            Text('chst', style: style, textScaler: TextScaler.noScaling),
          ],
        ),
      ),
    );
  }
}
