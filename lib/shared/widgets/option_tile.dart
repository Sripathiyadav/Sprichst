import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'design_widgets.dart';

/// How an [OptionTile] looks. After an answer is checked, the right answer is
/// [correct] even when the learner chose another, and their choice is
/// [incorrect]; both always show an icon and a word, never colour alone.
enum OptionState { idle, selected, correct, incorrect }

/// One choice: an answer in an exercise, a language or a goal in onboarding.
/// Tiles form a radio group, so each says whether it is selected.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    this.subtitle,
    this.marker,
    this.leading,
    this.state = OptionState.idle,
    this.onTap,
    this.locale,
  });

  final String label;
  final String? subtitle;

  /// "A", "B", "C" for answers.
  final String? marker;
  final IconData? leading;
  final OptionState state;
  final VoidCallback? onTap;

  /// German answers carry `Locale('de')` so screen readers pronounce them.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final (bg, border, width, word, icon, wordColor) = switch (state) {
      OptionState.idle => (t.surface, t.lineStrong, 1.5, null, null, t.ink),
      OptionState.selected => (
          t.accentSoft,
          t.ink,
          2.0,
          'Selected',
          Icons.radio_button_checked,
          t.ink
        ),
      OptionState.correct => (
          t.successSoft,
          t.success,
          2.0,
          'Correct',
          Icons.check_circle,
          t.success
        ),
      OptionState.incorrect => (
          t.dangerSoft,
          t.danger,
          2.0,
          'Not this one',
          Icons.cancel_outlined,
          t.danger
        ),
    };
    final selectedForSemantics =
        state == OptionState.selected || state == OptionState.correct;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selectedForSemantics,
      button: onTap != null,
      label: [
        if (marker != null) marker!,
        label,
        if (subtitle != null) subtitle!,
        if (word != null && state != OptionState.selected) word,
      ].join('. '),
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.quick(context),
        curve: AppMotion.curve,
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            side: BorderSide(color: border, width: width),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(AppRadius.control)),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    if (marker != null) ...[
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: t.lineStrong),
                        ),
                        child:
                            Text(marker!, style: theme.textTheme.labelMedium),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ] else if (leading != null) ...[
                      Icon(leading, color: t.ink),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              locale: locale,
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(color: t.ink)),
                          if (subtitle != null)
                            Text(subtitle!,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: t.inkMuted)),
                        ],
                      ),
                    ),
                    if (word != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      if (state != OptionState.selected)
                        Text(word,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: wordColor)),
                      const SizedBox(width: AppSpacing.xxs),
                      Icon(icon, color: wordColor, size: 22),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
