import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';

class PageFrame extends StatelessWidget {
  const PageFrame(
      {super.key,
      required this.title,
      this.subtitle,
      required this.child,
      this.trailing});

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < Breakpoints.narrowContent;
            final horizontal = compact ? AppSpacing.md : AppSpacing.lg;
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ],
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
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (trailing == null)
                        heading
                      else if (compact) ...[
                        heading,
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                            alignment: Alignment.centerRight, child: trailing!),
                      ] else
                        Row(
                          children: [
                            Expanded(child: heading),
                            trailing!,
                          ],
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            );
          },
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
  Widget build(BuildContext context) => Card(
        color: color,
        child: Padding(padding: padding, child: child),
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('${(value * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: compact ? 5 : 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: compact ? 7 : 10,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: PageFrame(
          title: title,
          subtitle: subtitle,
          child: ListView(children: children),
        ),
      );
}

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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(description!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(children: _withDividers(context, children)),
            ),
          ],
        ),
      );

  List<Widget> _withDividers(BuildContext context, List<Widget> items) {
    return [
      for (var index = 0; index < items.length; index++) ...[
        items[index],
        if (index != items.length - 1) const Divider(height: 1),
      ],
    ];
  }
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
        : Theme.of(context).colorScheme.primary;

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

Future<bool> showSprichstConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(dialogContext).colorScheme.error,
                      foregroundColor:
                          Theme.of(dialogContext).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}
