import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/learning/study_time.dart';

/// [StudyTimeStore] in `shared_preferences`, one entry per account so a second
/// learner on the same device never sees the first one's week. Nothing here
/// leaves the device.
class SharedPrefsStudyTimeStore implements StudyTimeStore {
  SharedPrefsStudyTimeStore(this._uid);

  /// The signed-in learner, or null when nobody is.
  final String? Function() _uid;

  String? get _key {
    final uid = _uid();
    return uid == null ? null : 'sprichst_study_time_v1_$uid';
  }

  @override
  Future<StudyTime> load() async {
    final key = _key;
    if (key == null) return const StudyTime();
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return const StudyTime();
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return StudyTime({
        for (final entry in data.entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      });
    } catch (_) {
      return const StudyTime(); // a damaged entry is no entry
    }
  }

  @override
  Future<void> save(StudyTime time) async {
    final key = _key;
    if (key == null) return;
    await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(time.seconds));
  }

  @override
  Future<void> clear() async {
    final key = _key;
    if (key == null) return;
    await (await SharedPreferences.getInstance()).remove(key);
  }
}
