import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import 'app_widgets.dart';

/// The top of a main screen, in the layout Home introduced: a row with the
/// screen's one number on the left (70%) and the level gauge on the right
/// (30%), then a full-width meter, then the one action. Enlarged text stacks
/// the row so nothing is squeezed.
class SummaryBlock extends StatelessWidget {
  const SummaryBlock({
    super.key,
    required this.lead,
    required this.level,
    required this.levelProgress,
    this.replay = 0,
    required this.meterLabel,
    required this.meterValue,
    this.meterValueLabel,
    this.action,
  });

  /// The screen's number (an [EditorialNumber]) or a short invitation.
  final Widget lead;
  final CefrLevel level;
  final double levelProgress;

  /// Changing this plays the gauge's sweep again.
  final int replay;

  final String meterLabel;
  final double meterValue;
  final String? meterValueLabel;

  /// The one next step, usually a [PrimaryButton] with `block: true`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final gauge =
        LevelGauge(level: level, progress: levelProgress, replay: replay);
    final enlarged = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final top = enlarged
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              lead,
              const SizedBox(height: AppSpacing.lg),
              SizedBox(width: 130, child: gauge),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 7,
                child: Align(alignment: Alignment.centerLeft, child: lead),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 3, child: gauge),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          const SizedBox(height: AppSpacing.xl),
          SkillMeter(
            label: meterLabel,
            value: meterValue,
            valueLabel: meterValueLabel,
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
