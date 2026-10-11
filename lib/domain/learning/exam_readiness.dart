import '../models/curriculum.dart';
import '../models/learning_models.dart';
import 'exercise_evaluator.dart';

/// Where the learner stands on one exam module.
enum ReadinessStatus { notStarted, building, onTrack }

class PillarReadiness {
  const PillarReadiness({
    required this.area,
    required this.module,
    required this.accuracy,
    required this.attempts,
    required this.status,
  });

  final SkillArea area;

  /// The module's German name: Lesen, Hören, Schreiben, Sprechen.
  final String module;
  final double accuracy;
  final int attempts;
  final ReadinessStatus status;
}

/// The four skills the Goethe-Zertifikat and TestDaF both test, in the order
/// the exams present them.
const examPillars = <(SkillArea, String)>[
  (SkillArea.reading, 'Lesen'),
  (SkillArea.listening, 'Hören'),
  (SkillArea.writing, 'Schreiben'),
  (SkillArea.speaking, 'Sprechen'),
];

/// A practice-based estimate of readiness for each exam module.
///
/// It is not an official prediction. The Goethe-Zertifikat is passed module by
/// module at 60%, so 60% is the line shown. TestDaF reports levels (TDN 3–5)
/// that depend on each test set, so for TestDaF the figure is only a guide.
class ExamReadiness {
  const ExamReadiness._(this.pillars);

  static const passMark = .6;
  static const minAttempts = 5;
  static const confidentAttempts = 8;

  final List<PillarReadiness> pillars;

  factory ExamReadiness.of(LearningProfile profile) => ExamReadiness._([
        for (final (area, module) in examPillars)
          _pillar(profile.areaStats[area.name], area, module),
      ]);

  static PillarReadiness _pillar(
      SkillStat? stat, SkillArea area, String module) {
    final attempts = stat?.attempts ?? 0;
    final accuracy = stat?.accuracy ?? 0;
    final status = attempts < minAttempts
        ? ReadinessStatus.notStarted
        : accuracy >= passMark && attempts >= confidentAttempts
            ? ReadinessStatus.onTrack
            : ReadinessStatus.building;
    return PillarReadiness(
      area: area,
      module: module,
      accuracy: accuracy,
      attempts: attempts,
      status: status,
    );
  }

  bool get onTrack => pillars.every((p) => p.status == ReadinessStatus.onTrack);

  /// The module that most needs attention, or null when none has started.
  PillarReadiness? get weakest {
    final started =
        pillars.where((p) => p.status != ReadinessStatus.notStarted).toList();
    if (started.isEmpty) return null;
    return started.reduce((a, b) => b.accuracy < a.accuracy ? b : a);
  }
}

/// One module of a mock exam.
class MockExamSection {
  const MockExamSection({
    required this.area,
    required this.module,
    required this.exercises,
  });

  final SkillArea area;
  final String module;
  final List<Exercise> exercises;
}

/// A short exam rehearsal: a few tasks per module, drawn from exam-style
/// lessons at or below the learner's level, preferring tasks not yet tried.
class MockExam {
  const MockExam(this.sections);

  /// Tasks per module: more reading and listening items, fewer long productions.
  static const perSection = {
    SkillArea.reading: 4,
    SkillArea.listening: 3,
    SkillArea.writing: 1,
    SkillArea.speaking: 2,
  };

  final List<MockExamSection> sections;

  List<Exercise> get exercises => [for (final s in sections) ...s.exercises];
  bool get isEmpty => exercises.isEmpty;

  factory MockExam.build(LearningProfile profile, Curriculum curriculum) {
    final family = profile.goal.exam ?? 'goethe';
    final pools = <SkillArea, List<Exercise>>{};
    for (final lesson in curriculum.lessons) {
      if (lesson.exam != family) continue;
      if (lesson.level.index > profile.currentLevel.index) continue;
      for (final exercise in lesson.exercises) {
        if (exercise.examPart == null) continue;
        pools.putIfAbsent(exercise.area, () => []).add(exercise);
      }
    }

    return MockExam([
      for (final (area, module) in examPillars)
        if (pools[area]?.isNotEmpty ?? false)
          MockExamSection(
            area: area,
            module: module,
            exercises: _pick(
              pools[area]!,
              profile,
              perSection[area] ?? 2,
            ),
          ),
    ]);
  }

  /// Untried tasks first, then those answered longest ago. A stable sort keeps
  /// curriculum order among equals, so the exam is deterministic.
  static List<Exercise> _pick(
    List<Exercise> pool,
    LearningProfile profile,
    int count,
  ) {
    final ranked = [...pool]..sort((a, b) {
        final seenA = profile.exerciseStats[a.id]?.lastAnsweredAt;
        final seenB = profile.exerciseStats[b.id]?.lastAnsweredAt;
        if (seenA == null && seenB == null) return 0;
        if (seenA == null) return -1;
        if (seenB == null) return 1;
        return seenA.compareTo(seenB);
      });
    return ranked.take(count).toList();
  }
}

/// How the learner did on a mock exam, module by module.
class ExamReport {
  const ExamReport._(this.sections, this.overall);

  factory ExamReport.from(MockExam exam, List<ExerciseResult> results) {
    final scoreById = {
      for (final r in results.where((r) => !r.isRetry)) r.exercise.id: r.score,
    };
    final sections = <ExamSectionResult>[];
    for (final section in exam.sections) {
      final scores = [
        for (final e in section.exercises) scoreById[e.id] ?? 0.0,
      ];
      final score = scores.isEmpty
          ? 0.0
          : scores.fold<double>(0, (a, b) => a + b) / scores.length;
      sections.add(ExamSectionResult(
        module: section.module,
        score: score,
        passed: score >= ExamReadiness.passMark,
      ));
    }
    final overall = sections.isEmpty
        ? 0.0
        : sections.fold<double>(0, (a, s) => a + s.score) / sections.length;
    return ExamReport._(sections, overall);
  }

  final List<ExamSectionResult> sections;
  final double overall;

  /// Goethe modules are passed one by one, so passing means every module.
  bool get passedAll => sections.isNotEmpty && sections.every((s) => s.passed);
}

class ExamSectionResult {
  const ExamSectionResult({
    required this.module,
    required this.score,
    required this.passed,
  });

  final String module;
  final double score;
  final bool passed;
}
