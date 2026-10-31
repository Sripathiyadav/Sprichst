import 'flashcard_deck.dart' show dayKey;

/// Time spent studying, per local day, for the last two weeks. It feeds the
/// "This week" chart on Home and Progress.
///
/// Stored as seconds so many short sessions add up without each one being
/// rounded. It stays on the device (see [StudyTimeStore]); it is not part of
/// the synced profile.
class StudyTime {
  const StudyTime([this.seconds = const {}]);

  /// Seconds studied, keyed by [dayKey].
  final Map<String, int> seconds;

  /// Days older than this are dropped on every write.
  static const keepDays = 14;

  /// The most one session can add. A screen left open over lunch is not an
  /// hour of German.
  static const maxSession = Duration(minutes: 60);

  /// Whole minutes studied on the local day of [day].
  int minutesOn(DateTime day) => (seconds[dayKey(day)] ?? 0) ~/ 60;

  /// Adds [spent] to the day of [now] and forgets days older than [keepDays].
  StudyTime add(Duration spent, DateTime now) {
    if (spent <= Duration.zero) return this;
    final capped = spent > maxSession ? maxSession : spent;
    final today = dayKey(now);
    final oldest =
        dayKey(DateTime(now.year, now.month, now.day - keepDays + 1));
    return StudyTime({
      for (final entry in seconds.entries)
        if (entry.key.compareTo(oldest) >= 0) entry.key: entry.value,
      today: (seconds[today] ?? 0) + capped.inSeconds,
    });
  }

  /// Monday to Sunday of the week that contains [now], with the minutes of
  /// each day.
  List<({DateTime day, int minutes})> week(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        (
          day: DateTime(monday.year, monday.month, monday.day + i),
          minutes:
              minutesOn(DateTime(monday.year, monday.month, monday.day + i)),
        ),
    ];
  }

  /// Total whole minutes in the week that contains [now].
  int weekMinutes(DateTime now) =>
      week(now).fold(0, (sum, day) => sum + day.minutes);
}

/// Where [StudyTime] is kept. One per signed-in learner, on this device only.
abstract class StudyTimeStore {
  Future<StudyTime> load();
  Future<void> save(StudyTime time);
  Future<void> clear();
}

/// Keeps study time in memory. For tests and for builds without storage.
class MemoryStudyTimeStore implements StudyTimeStore {
  StudyTime _time = const StudyTime();

  @override
  Future<StudyTime> load() async => _time;

  @override
  Future<void> save(StudyTime time) async => _time = time;

  @override
  Future<void> clear() async => _time = const StudyTime();
}
