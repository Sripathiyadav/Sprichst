import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style:
                                    Theme.of(context).textTheme.displaySmall),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(subtitle!,
                                  style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      );
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
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
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
              backgroundColor: SprichstTheme.sand,
              color: SprichstTheme.forest,
            ),
          ),
        ],
      );
}
