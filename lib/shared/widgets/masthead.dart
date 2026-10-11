import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'wordmark.dart';

/// The masthead at the top of every screen: a 1.5px ink rule, the wordmark row
/// with up to two actions, then a hairline.
///
/// [Masthead] sits inside a page (tab roots); [MastheadBar] is the same thing
/// as an app bar for pushed pages, with a back button.
class Masthead extends StatelessWidget {
  const Masthead(
      {super.key, this.actions = const [], this.leading, this.onLogoTap});

  final List<Widget> actions;
  final Widget? leading;

  /// Makes the wordmark a button (Home uses it to refresh).
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1.5, color: t.ink),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              if (leading != null) leading!,
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: leading == null ? 0 : 4),
                    child: onLogoTap == null
                        ? const Wordmark()
                        : Semantics(
                            button: true,
                            label: 'Refresh',
                            excludeSemantics: true,
                            child: InkWell(
                              key: const ValueKey('logo-refresh'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: onLogoTap,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                    horizontal: AppSpacing.xxs),
                                child: Wordmark(),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Container(height: 1, color: t.line),
      ],
    );
  }
}

/// [Masthead] as the app bar of a pushed page. The back button appears on its
/// own when there is somewhere to go back to.
class MastheadBar extends StatelessWidget implements PreferredSizeWidget {
  const MastheadBar(
      {super.key, this.actions = const [], this.eyebrow, this.leading});

  final List<Widget> actions;

  /// Replaces the back button (a close button that ends a session).
  final Widget? leading;

  /// Context in capitals under the hairline, e.g. "LESSON 08 · A1 · DAILY LIFE".
  final String? eyebrow;

  static const _rule = 1.5;
  static const _row = 56.0;
  static const _hairline = 1.0;
  static const _eyebrowRow = 32.0;

  @override
  Size get preferredSize => Size.fromHeight(
      _rule + _row + _hairline + (eyebrow == null ? 0 : _eyebrowRow));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final canPop = Navigator.canPop(context);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: _rule, color: t.ink),
            SizedBox(
              height: _row,
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else if (canPop)
                    const BackButton()
                  else
                    const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft, child: Wordmark()),
                  ),
                  ...actions,
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
            ),
            Container(height: _hairline, color: t.line),
            if (eyebrow != null)
              SizedBox(
                height: _eyebrowRow,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(eyebrow!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
