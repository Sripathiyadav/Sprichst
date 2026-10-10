import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import 'glass.dart';

export 'glass.dart';

class PageFrame extends StatefulWidget {
  const PageFrame(
      {super.key,
      required this.title,
      this.subtitle,
      required this.child,
      this.trailing,
      this.scrollsUnderNav = true});

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

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

  /// Large title that folds into a compact one once the list scrolls (the
  /// Apple large-title pattern): the heading stays, the subtitle gets out of
  /// the way, and the content gets the room.
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
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : const Duration(milliseconds: 220);

    return SafeArea(
      bottom: !widget.scrollsUnderNav,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < Breakpoints.narrowContent;
          // Enlarged text or a short window leaves little room: the subtitle is
          // supporting text, so it yields before the content does.
          final scale = MediaQuery.textScalerOf(context).scale(1);
          // The avatar sits beside the title unless the row would be cramped.
          final stackTrailing =
              constraints.maxWidth < Breakpoints.stackTrailing || scale >= 1.5;
          final showSubtitle = widget.subtitle != null &&
              constraints.maxHeight / scale >= Breakpoints.subtitleMinHeight;
          final horizontal = compact ? AppSpacing.md : AppSpacing.lg;
          final subtitle = widget.subtitle == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child:
                      Text(widget.subtitle!, style: theme.textTheme.bodyLarge),
                );
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeOutCubic,
                style: (_collapsed
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.displaySmall) ??
                    const TextStyle(),
                child: Semantics(header: true, child: Text(widget.title)),
              ),
              if (showSubtitle)
                // With reduced motion the subtitle just goes; an AnimatedSize
                // with no duration would re-layout itself mid-layout.
                still
                    ? (_collapsed ? const SizedBox.shrink() : subtitle)
                    : AnimatedSize(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topLeft,
                        child: _collapsed
                            ? const SizedBox(width: double.infinity)
                            : subtitle,
                      ),
            ],
          );
          final gap = AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            height: _collapsed ? AppSpacing.md : AppSpacing.xl,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  compact ? AppSpacing.lg : 26,
                  horizontal,
                  widget.scrollsUnderNav ? 0 : AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.trailing == null)
                      heading
                    else if (stackTrailing) ...[
                      heading,
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                          alignment: Alignment.centerRight,
                          child: widget.trailing!),
                    ] else
                      Row(
                        children: [
                          Expanded(child: heading),
                          widget.trailing!,
                        ],
                      ),
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

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null) action!,
        ],
      );
}

class SkillMeter extends StatelessWidget {
  const SkillMeter(
      {super.key,
      required this.label,
      required this.value,
      this.compact = false});

  final String label;
  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Semantics(
      label: label,
      value: '$percent percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('$percent%',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 15)),
            ],
          ),
          SizedBox(height: compact ? 5 : 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: compact ? 8 : 12,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: context.accent,
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
        // No title in the bar: the page heading below says it, and folds up
        // to a compact title as the list scrolls.
        appBar: AppBar(),
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
              left: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
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
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: Icon(icon, color: color),
      title: Text(title, style: destructive ? TextStyle(color: color) : null),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
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

/// The German flag's three bands as a slim decorative accent. Purely visual,
/// so hidden from assistive technology; the hairline keeps the black band
/// visible against dark backgrounds.
class FlagStripe extends StatelessWidget {
  const FlagStripe({
    super.key,
    this.height = 6,
    this.radius = 99,
    this.outline,
  });

  final double height;
  final double radius;

  /// Hairline drawn around the stripe so the band matching the backdrop (black
  /// on black, gold on gold) stays visible. Defaults to a neutral outline.
  final Color? outline;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: outline ?? Theme.of(context).colorScheme.outlineVariant,
              width: outline == null ? .5 : 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              height: height,
              // Container (not ColoredBox) so each band fills its slot: a
              // child-less ColoredBox collapses to zero height inside a Row.
              child: Row(
                children: [
                  for (final color in const [
                    FlagColors.black,
                    FlagColors.red,
                    FlagColors.gold,
                  ])
                    Expanded(child: Container(color: color)),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Correct / not-quite feedback. Colour is reinforced by an icon and a heading,
/// and the message is announced to screen readers as it appears.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    super.key,
    required this.correct,
    required this.message,
  });

  final bool correct;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = correct ? context.successSurface : context.dangerSurface;
    final foreground =
        correct ? context.onSuccessSurface : context.onDangerSurface;
    final heading = correct ? 'Correct!' : 'Not quite';
    return Semantics(
      liveRegion: true,
      container: true,
      label: '$heading $message',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(correct ? Icons.check_circle : Icons.cancel_outlined,
                  color: foreground, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: foreground)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(message,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: foreground)),
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

/// A single number with an icon and a plain-language label.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: SoftCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.softSurface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                child: Icon(icon),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Animation length that respects the platform's reduce-motion setting.
Duration motionDuration(BuildContext context, [int milliseconds = 200]) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);
