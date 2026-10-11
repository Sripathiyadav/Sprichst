import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import 'design_widgets.dart';
import 'glass.dart';
import 'masthead.dart';

export 'design_widgets.dart';
export 'geometry.dart';
export 'glass.dart';
export 'masthead.dart';
export 'option_tile.dart';
export 'wordmark.dart';

class PageFrame extends StatefulWidget {
  const PageFrame(
      {super.key,
      required this.title,
      this.subtitle,
      required this.child,
      this.trailing,
      this.eyebrow,
      this.titleLocale,
      this.compactHeading = false,
      this.scrollsUnderNav = true});

  final String title;
  final String? subtitle;
  final Widget child;

  /// Sits in the masthead row (the profile avatar, a settings button).
  final Widget? trailing;

  /// Context in capitals above the title ("FRIDAY, 9 OCTOBER").
  final String? eyebrow;

  /// Always shows the small heading and no eyebrow or subtitle, for screens
  /// that are one fixed layout (the coach) and need the height.
  final bool compactHeading;

  /// Set to German when the title is a German phrase, so screen readers
  /// pronounce it correctly.
  final Locale? titleLocale;

  /// Whether [child] is a scrollable that may run beneath the floating
  /// navigation bar. A scrollable pads itself by the inset it is given (use
  /// [pageListPadding]); a fixed layout such as the Coach screen must instead be
  /// kept clear of the bar, so it sets this to false.
  final bool scrollsUnderNav;

  /// How far the page must scroll before the heading folds up, and how close to
  /// the top it must come back before the heading opens again. The gap stops
  /// the heading flickering when a scroll hovers near the threshold.
  static const collapseAfter = 24.0;
  static const expandBefore = 4.0;

  /// A list must have this much to scroll before the heading folds, because
  /// folding gives the list room: a list that only just overflows would stop
  /// overflowing, snap back, and fold again on every nudge.
  static const minScrollForCollapse = 200.0;

  @override
  State<PageFrame> createState() => _PageFrameState();
}

class _PageFrameState extends State<PageFrame> {
  var _collapsed = false;

  /// The large title folds into a compact one once the list scrolls: the
  /// heading stays, the subtitle gets out of the way, and the content gets the
  /// room.
  bool _onScroll(ScrollNotification note) {
    if (note.depth != 0 || note.metrics.axis != Axis.vertical) return false;
    final pixels = note.metrics.pixels;
    final next = _collapsed
        ? pixels > PageFrame.expandBefore
        : pixels > PageFrame.collapseAfter &&
            note.metrics.maxScrollExtent > PageFrame.minScrollForCollapse;
    if (next != _collapsed) {
      // Notifications can arrive while the tree is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _collapsed = next);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : const Duration(milliseconds: 200);
    final collapsed = _collapsed || widget.compactHeading;

    return SafeArea(
      bottom: !widget.scrollsUnderNav,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < Breakpoints.narrowContent;
          // Enlarged text or a short window leaves little room: the subtitle is
          // supporting text, so it yields before the content does.
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final showSubtitle = widget.subtitle != null &&
              constraints.maxHeight / scale >= Breakpoints.subtitleMinHeight;
          final horizontal = compact ? AppSpacing.md : AppSpacing.lg;

          final subtitle = widget.subtitle == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(widget.subtitle!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: t.inkMuted)),
                );
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.eyebrow != null && !collapsed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(widget.eyebrow!.toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: t.accent)),
                ),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: AppMotion.curve,
                style: (collapsed
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.displaySmall) ??
                    const TextStyle(),
                child: Semantics(
                    header: true,
                    child: Text(widget.title, locale: widget.titleLocale)),
              ),
              if (showSubtitle)
                // With reduced motion the subtitle just goes; an AnimatedSize
                // with no duration would re-layout itself mid-layout.
                still
                    ? (collapsed ? const SizedBox.shrink() : subtitle)
                    : AnimatedSize(
                        duration: duration,
                        curve: AppMotion.curve,
                        alignment: Alignment.topLeft,
                        child: collapsed
                            ? const SizedBox(width: double.infinity)
                            : subtitle,
                      ),
            ],
          );
          final gap = AnimatedContainer(
            duration: duration,
            curve: AppMotion.curve,
            height: collapsed ? AppSpacing.sm : AppSpacing.lg,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  compact ? AppSpacing.xs : AppSpacing.md,
                  horizontal,
                  widget.scrollsUnderNav ? 0 : AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Masthead(
                        leading: Navigator.canPop(context)
                            ? const BackButton()
                            : null,
                        actions: [
                          if (widget.trailing != null) widget.trailing!
                        ]),
                    const SizedBox(height: AppSpacing.lg),
                    heading,
                    gap,
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom padding for a page's main scrollable: a comfortable gap plus whatever
/// inset the screen has (the floating navigation bar or the home indicator), so
/// the last item can scroll fully clear while earlier ones pass beneath.
EdgeInsets pageListPadding(BuildContext context) => EdgeInsets.only(
      bottom: AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
    );

/// A full-screen page: the ambient backdrop with a transparent [Scaffold] on top,
/// so Liquid Glass has light to catch and routes never show the page behind them
/// while animating. With standard surfaces it is an ordinary page.
class GlassPage extends StatelessWidget {
  const GlassPage({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.extendBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  @override
  Widget build(BuildContext context) => AmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
          extendBody: extendBody,
        ),
      );
}

/// A centered, width-limited, scrollable column for focused single-task screens
/// (sign-in, onboarding) so they never overflow on short or landscape windows.
class CenteredScroll extends StatelessWidget {
  const CenteredScroll({super.key, required this.child, this.maxWidth = 520});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      );
}

/// A circular avatar showing the first letter of [name].
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.radius,
    this.filled = false,
  });

  final String name;
  final double? radius;

  /// Uses the brand color instead of the soft surface.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: filled ? scheme.primary : context.softSurface,
      foregroundColor: filled ? scheme.onPrimary : null,
      child:
          Text(trimmed.isEmpty ? 'S' : trimmed.characters.first.toUpperCase()),
    );
  }
}

/// The app's standard card: a plain bordered card, or Liquid Glass when the
/// learner has chosen it. [color] tints the card (for emphasis) instead of using
/// the default surface colour.
class SoftCard extends StatelessWidget {
  const SoftCard(
      {super.key,
      required this.child,
      this.color,
      this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => GlassSurface(
        tint: color,
        padding: padding,
        child: child,
      );
}

/// The small capitals label that opens a section, with an optional quiet link
/// on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
          if (action != null) action!,
        ],
      );
}

/// A labelled 8px bar for skill scores, lesson progress and the daily goal. The
/// number is always shown as text too; the bar only illustrates it.
class SkillMeter extends StatelessWidget {
  const SkillMeter(
      {super.key,
      required this.label,
      required this.value,
      this.valueLabel,
      this.onPanel = false,
      this.compact = false});

  final String label;
  final double value;

  /// Replaces the percentage ("9 / 15 min").
  final String? valueLabel;

  /// Colours for a bar that sits inside a [FeaturePanel].
  final bool onPanel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final percent = (value * 100).round();
    final shown = valueLabel ?? '$percent%';
    return Semantics(
      label: label,
      value: valueLabel ?? '$percent percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: onPanel ? t.onPanelMuted : t.inkMuted)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(shown,
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: onPanel ? t.onPanel : t.ink,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          SizedBox(height: compact ? 5 : AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 8,
              backgroundColor: onPanel ? t.lineOnPanel : t.surfaceSunken,
              color: onPanel ? t.accentOnPanel : t.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassPage(
        // The masthead carries the wordmark; the page heading below says what
        // this page is, and folds up to a compact title as the list scrolls.
        body: PageFrame(
          title: title,
          subtitle: subtitle,
          child: ListView(
            padding: pageListPadding(context),
            children: children,
          ),
        ),
      );
}

/// An inset grouped list section, as in iOS Settings: a small header above, a
/// rounded group of rows with inset separators, and an optional footer below.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(children: _withDividers(children)),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxs,
                AppSpacing.xs,
                AppSpacing.xxs,
                0,
              ),
              child: Text(description!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  /// Separators start where the text does, leaving the icon column clear.
  List<Widget> _withDividers(List<Widget> items) => [
        for (var index = 0; index < items.length; index++) ...[
          items[index],
          if (index != items.length - 1)
            const Divider(height: 1, indent: AppSpacing.md + 40),
        ],
      ];
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// A destructive row (remove key, delete account): crimson, and always
  /// confirmed first.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = destructive ? t.danger : t.ink;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          (onTap == null ? null : Icon(Icons.chevron_right, color: t.inkMuted)),
      onTap: onTap,
    );
  }
}

/// A confirmation alert that looks native: Cupertino on Apple platforms,
/// Material elsewhere.
Future<bool> showSprichstConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  return await showAdaptiveDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final apple = theme.platform == TargetPlatform.iOS ||
              theme.platform == TargetPlatform.macOS;

          void close(bool confirmed) =>
              Navigator.of(dialogContext).pop(confirmed);

          return AlertDialog.adaptive(
            title: Text(title),
            content: Text(message),
            actions: apple
                ? [
                    CupertinoDialogAction(
                      onPressed: () => close(false),
                      child: const Text('Cancel'),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: destructive,
                      isDefaultAction: !destructive,
                      onPressed: () => close(true),
                      child: Text(confirmLabel),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => close(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      style: destructive
                          ? TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error)
                          : null,
                      onPressed: () => close(true),
                      child: Text(confirmLabel),
                    ),
                  ],
          );
        },
      ) ??
      false;
}

/// How an inline message reads. Each tone pairs an icon with a word; colour
/// alone never says it.
enum BannerTone { success, danger, warning, info, offline }

/// An inline message for answer feedback, warnings and connection status. After
/// an answer the title gives the verdict ("Correct", "Not quite") and the body
/// gives the curriculum's explanation, never a judgement of the learner.
/// `danger` is announced as an alert, every other tone as a status.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Feedback on an answer.
  const FeedbackBanner.answer({
    Key? key,
    required bool correct,
    required String message,
  }) : this(
          key: key,
          tone: correct ? BannerTone.success : BannerTone.danger,
          title: correct ? 'Correct' : 'Not quite',
          message: message,
        );

  final BannerTone tone;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final (bg, fg, icon) = switch (tone) {
      BannerTone.success => (t.successSoft, t.success, Icons.check_circle),
      BannerTone.danger => (t.dangerSoft, t.danger, Icons.cancel_outlined),
      BannerTone.warning => (
          t.warningSoft,
          t.warning,
          Icons.warning_amber_rounded
        ),
      BannerTone.info => (t.surfaceSunken, t.ink, Icons.info_outline),
      BannerTone.offline => (t.surfaceSunken, t.ink, Icons.cloud_off),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $message',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall?.copyWith(color: fg)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(message, style: theme.textTheme.bodyLarge),
                    if (actionLabel != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact statistic: a light numeral, a label and an optional caption. Every
/// value comes from the learner's real history.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.caption,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Semantics(
      label: '$value $label${caption == null ? '' : ', $caption'}',
      excludeSemantics: true,
      child: SoftCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: t.ink, size: 20),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: theme.textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: theme.textTheme.labelLarge),
            if (caption != null)
              Text(caption!,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// Animation length that respects the platform's reduce-motion setting.
Duration motionDuration(BuildContext context, [int milliseconds = 200]) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);
