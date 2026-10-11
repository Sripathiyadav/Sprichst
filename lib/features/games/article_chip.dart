import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// der / die / das have long had colours in German classrooms (blue, red,
/// green). The article is always written on the chip too, so colour is only a
/// reinforcement, never the sole cue.
class ArticleColors {
  const ArticleColors._(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const _hues = {'der': 250.0, 'die': 25.0, 'das': 140.0};

  static ArticleColors of(String article, Brightness brightness) {
    final palette = TonalPalette.of(_hues[article] ?? 0, 48);
    final dark = brightness == Brightness.dark;
    return ArticleColors._(
      Color(palette.get(dark ? 30 : 90)),
      Color(palette.get(dark ? 90 : 10)),
    );
  }
}

class ArticleChip extends StatelessWidget {
  const ArticleChip(this.article, {super.key, this.large = false});

  final String article;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = ArticleColors.of(article, Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 20 : 12,
          vertical: large ? 8 : 4,
        ),
        child: Text(
          article,
          style: (large
                  ? Theme.of(context).textTheme.headlineSmall
                  : Theme.of(context).textTheme.labelLarge)
              ?.copyWith(color: colors.foreground),
        ),
      ),
    );
  }
}
