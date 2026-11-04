import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/local_learning_repository.dart';
import '../../domain/repositories/learning_repository.dart';

/// A guest's progress, on this device only. It moves to the account when the
/// guest signs in (see `GuestUpgradeView`).
final guestRepositoryProvider = Provider<LearningRepository>(
    (ref) => LocalLearningRepository(profileKey: 'sprichst_guest_profile_v1'));

/// Whether the learner chose to continue without an account. Null while the
/// remembered choice is still being read.
final guestModeProvider = NotifierProvider<GuestMode, bool?>(GuestMode.new);

class GuestMode extends Notifier<bool?> {
  static const _key = 'sprichst_guest_v1';

  @override
  bool? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    var on = false;
    try {
      on = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      // No storage (tests, a locked-down browser): start signed out.
    }
    if (state == null) state = on;
  }

  Future<void> start() => _set(true);
  Future<void> end() => _set(false);

  Future<void> _set(bool on) async {
    state = on;
    try {
      final preferences = await SharedPreferences.getInstance();
      on
          ? await preferences.setBool(_key, true)
          : await preferences.remove(_key);
    } catch (_) {
      // Remembered for this session only.
    }
  }
}

/// One-time nudges to add an account: the Home banner and the prompt after
/// the first lesson. Holds the names already seen; null while loading.
final guestHintsProvider =
    NotifierProvider<GuestHints, Set<String>?>(GuestHints.new);

class GuestHints extends Notifier<Set<String>?> {
  static const _key = 'sprichst_guest_hints_v1';
  static const homeBanner = 'home_banner';
  static const firstLesson = 'first_lesson';

  @override
  Set<String>? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    var seen = <String>{};
    try {
      seen = {...?(await SharedPreferences.getInstance()).getStringList(_key)};
    } catch (_) {}
    state ??= seen;
  }

  bool hasSeen(String hint) => state?.contains(hint) ?? true;

  Future<void> markSeen(String hint) async {
    state = {...?state, hint};
    try {
      await (await SharedPreferences.getInstance())
          .setStringList(_key, state!.toList());
    } catch (_) {}
  }
}
