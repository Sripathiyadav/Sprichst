import '../models/learning_models.dart';

/// What the app has observed about how this learner learns.
///
/// This is deliberately not a "learning style" quiz. Research has not found that
/// teaching to a stated visual or auditory preference improves results. What does
/// work, and what can be measured, is how well someone recognises answers versus
/// produces them, which skills lag behind, and how regularly they practise. The
/// insights below come from the learner's actual answers.
enum InsightKind { productionGap, weakestMode, strength, consistency, learning }

class LearnerInsight {
  const LearnerInsight({
    required this.kind,
    required this.title,
    required this.detail,
    this.action,
  });

  final InsightKind kind;
  final String title;
  final String detail;

  /// What Sprichst does about it.
  final String? action;
}

class LearnerInsights {
  const LearnerInsights._();

  /// Evidence needed before an insight is shown, so early luck or bad luck does
  /// not label a learner.
  static const minRecognitionAttempts = 6;
  static const minProductionAttempts = 4;
  static const minKindAttempts = 4;
  static const _gap = .2;

  static List<ExerciseKind> get _recognitionKinds => [
        for (final k in ExerciseKind.values)
          if (k.isRecognition) k
      ];
  static List<ExerciseKind> get _productionKinds => [
        for (final k in ExerciseKind.values)
          if (!k.isRecognition) k
      ];

  /// Smoothed accuracy over [kinds], or null with too little evidence.
  static double? accuracy(
    LearningProfile profile,
    Iterable<ExerciseKind> kinds, {
    required int minAttempts,
  }) {
    var attempts = 0;
    var correct = 0;
    for (final kind in kinds) {
      final stat = profile.kindStats[kind.name];
      if (stat == null) continue;
      attempts += stat.attempts;
      correct += stat.correct;
    }
    if (attempts < minAttempts) return null;
    return (correct + 1) / (attempts + 2);
  }

  static double? recognitionAccuracy(LearningProfile profile) =>
      accuracy(profile, _recognitionKinds, minAttempts: minRecognitionAttempts);

  static double? productionAccuracy(LearningProfile profile) =>
      accuracy(profile, _productionKinds, minAttempts: minProductionAttempts);

  /// Recognition is clearly ahead of production: the classic gap that spaced
  /// recall and typing practice close.
  static bool hasProductionGap(LearningProfile profile) {
    final recognition = recognitionAccuracy(profile);
    final production = productionAccuracy(profile);
    return recognition != null &&
        production != null &&
        recognition >= .75 &&
        recognition - production >= _gap;
  }

  /// 0 to 1: how much practising [kind] would help, from the learner's own
  /// record. Zero until there is enough evidence.
  static double need(LearningProfile profile, ExerciseKind kind) {
    final stat = profile.kindStats[kind.name];
    var need = 0.0;
    if (stat != null && stat.attempts >= 3) need = 1 - stat.accuracy;
    if (hasProductionGap(profile) && !kind.isRecognition) need += .3;
    return need.clamp(0.0, 1.0);
  }

  static List<LearnerInsight> build(LearningProfile profile, {int limit = 3}) {
    final total =
        profile.kindStats.values.fold<int>(0, (n, s) => n + s.attempts);
    if (total < 10) {
      return const [
        LearnerInsight(
          kind: InsightKind.learning,
          title: 'Sprichst is learning how you learn',
          detail:
              'After a few lessons it will show which kinds of practice suit you best and where you need more.',
        ),
      ];
    }

    final insights = <LearnerInsight>[];

    if (hasProductionGap(profile)) {
      final recognition = (recognitionAccuracy(profile)! * 100).round();
      final production = (productionAccuracy(profile)! * 100).round();
      insights.add(LearnerInsight(
        kind: InsightKind.productionGap,
        title: 'You recognise more than you can recall',
        detail:
            'Choosing answers: $recognition% right. Typing and building them yourself: $production%. That gap is normal, and recalling is what makes words stick.',
        action:
            'Sprichst now mixes in more typing, sentence building and flashcards.',
      ));
    }

    final weakest = _weakestKind(profile);
    if (weakest != null) {
      final stat = profile.kindStats[weakest.name]!;
      insights.add(LearnerInsight(
        kind: InsightKind.weakestMode,
        title: '${weakest.label} needs the most work',
        detail:
            '${(stat.accuracy * 100).round()}% right across ${stat.attempts} answers.',
        action:
            'Short ${weakest.label.toLowerCase()} practice is boosted in your sessions.',
      ));
    }

    final strongest = _strongestKind(profile);
    if (strongest != null) {
      final stat = profile.kindStats[strongest.name]!;
      insights.add(LearnerInsight(
        kind: InsightKind.strength,
        title: 'Strong at ${strongest.label.toLowerCase()}',
        detail:
            '${(stat.accuracy * 100).round()}% right across ${stat.attempts} answers. Sprichst gives you harder items here.',
      ));
    }

    final streak = profile.streak;
    insights.add(LearnerInsight(
      kind: InsightKind.consistency,
      title:
          streak >= 3 ? '$streak days in a row' : 'Little and often works best',
      detail: streak >= 3
          ? 'Regular short sessions beat occasional long ones, because spacing practice is what moves words into long-term memory.'
          : 'Ten minutes a day, spread out, helps memory more than one long session.',
    ));

    return insights.take(limit).toList();
  }

  static ExerciseKind? _weakestKind(LearningProfile profile) {
    ExerciseKind? weakest;
    var lowest = .6; // only flag kinds below this
    for (final kind in ExerciseKind.values) {
      final stat = profile.kindStats[kind.name];
      if (stat == null || stat.attempts < minKindAttempts) continue;
      if (stat.accuracy < lowest) {
        lowest = stat.accuracy;
        weakest = kind;
      }
    }
    return weakest;
  }

  static ExerciseKind? _strongestKind(LearningProfile profile) {
    ExerciseKind? strongest;
    var highest = .85;
    for (final kind in ExerciseKind.values) {
      final stat = profile.kindStats[kind.name];
      if (stat == null || stat.attempts < minRecognitionAttempts) continue;
      if (stat.accuracy >= highest) {
        highest = stat.accuracy;
        strongest = kind;
      }
    }
    return strongest;
  }
}
