import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/learning_models.dart';
import 'profile_codec.dart';

/// A copy of one learner's profile kept on this device.
abstract class ProfileCache {
  Future<LearningProfile?> load();
  Future<void> save(LearningProfile profile);

  /// Whether the cached copy holds changes the cloud has not received yet.
  Future<bool> hasPendingChanges();
  Future<void> setPendingChanges(bool pending);
  Future<void> clear();
}

/// [ProfileCache] in `shared_preferences`, one entry per account so a second
/// learner on the same device never sees the first one's progress.
class SharedPrefsProfileCache implements ProfileCache {
  SharedPrefsProfileCache(String uid)
      : _profileKey = 'sprichst_profile_cache_v1_$uid',
        _pendingKey = 'sprichst_profile_pending_v1_$uid';

  final String _profileKey;
  final String _pendingKey;

  @override
  Future<LearningProfile?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_profileKey);
    if (raw == null) return null;
    try {
      return ProfileCodec.decode(
        jsonDecode(raw) as Map<String, dynamic>,
        decodeDate: (value) => DateTime.parse(value as String),
      );
    } catch (_) {
      return null; // a damaged cache is no cache
    }
  }

  @override
  Future<void> save(LearningProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _profileKey,
      jsonEncode(ProfileCodec.encode(profile,
          encodeDate: (date) => date.toIso8601String())),
    );
  }

  @override
  Future<bool> hasPendingChanges() async =>
      (await SharedPreferences.getInstance()).getBool(_pendingKey) ?? false;

  @override
  Future<void> setPendingChanges(bool pending) async {
    final preferences = await SharedPreferences.getInstance();
    if (pending) {
      await preferences.setBool(_pendingKey, true);
    } else {
      await preferences.remove(_pendingKey);
    }
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_profileKey);
    await preferences.remove(_pendingKey);
  }
}

/// Keeps a learner's profile usable offline.
///
/// The policy, in full:
///
/// * The cloud is the source of truth. Every successful load or save refreshes
///   the on-device copy.
/// * A save always lands on the device first. If the cloud cannot be reached
///   ([isUnreachable]), the change is kept and flagged as pending; any other
///   failure (a rejected write, say) is an error and is rethrown.
/// * On the next load, pending changes win: they are newer than anything the
///   cloud has, because the cloud has not seen them. They are pushed, and the
///   flag is cleared once that works.
/// * If the cloud cannot be reached on load, the on-device copy is used, so a
///   learner on a train can keep studying.
///
/// Two devices changed offline at once resolve as last writer wins; the profile
/// is one document, so there is nothing finer-grained to merge.
class SyncedProfileStore {
  SyncedProfileStore({
    required this.cache,
    required this.loadRemote,
    required this.saveRemote,
    required this.isUnreachable,
    this.delay = Duration.zero,
  });

  final ProfileCache cache;
  final Future<LearningProfile?> Function() loadRemote;
  final Future<void> Function(LearningProfile profile) saveRemote;
  final bool Function(Object error) isUnreachable;

  /// How long to wait for more changes before writing to the cloud. A learner
  /// finishing exercises changes the profile many times a minute; writing once
  /// after the burst keeps the free Firestore quota (20,000 writes a day for
  /// the whole project) for more learners. Nothing is lost by waiting: every
  /// change is on the device at once and flagged pending until it is pushed.
  final Duration delay;

  Timer? _timer;
  LearningProfile? _latest;

  Future<LearningProfile?> load() async {
    if (await cache.hasPendingChanges()) {
      final local = await cache.load();
      if (local != null) {
        try {
          await saveRemote(local);
          await cache.setPendingChanges(false);
        } catch (_) {
          // Still offline (or rejected): keep studying from the local copy and
          // try again on the next save or load.
        }
        return local;
      }
      await cache
          .setPendingChanges(false); // flag without data: nothing to push
    }

    try {
      final remote = await loadRemote();
      if (remote != null) await cache.save(remote);
      return remote;
    } catch (error) {
      if (!isUnreachable(error)) rethrow;
      final local = await cache.load();
      if (local != null) return local;
      rethrow;
    }
  }

  Future<void> save(LearningProfile profile) async {
    await cache.save(profile);
    _latest = profile;
    if (delay == Duration.zero) return _push(rethrow_: true);

    // Flagged first, so a crash or a killed app still pushes it next time.
    await cache.setPendingChanges(true);
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(_push(rethrow_: false)));
  }

  /// Writes any change that is still waiting. Call when the app goes to the
  /// background and before signing out.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _latest == null ? Future.value() : _push(rethrow_: false);
  }

  Future<void> _push({required bool rethrow_}) async {
    final profile = _latest;
    if (profile == null) return;
    try {
      await saveRemote(profile);
      if (identical(profile, _latest)) {
        _latest = null;
        await cache.setPendingChanges(false);
      }
    } catch (error) {
      if (isUnreachable(error)) {
        await cache.setPendingChanges(true);
      } else if (rethrow_) {
        rethrow;
      } else {
        // Nobody is waiting on a background write; it stays pending and is
        // tried again on the next save or load.
        debugPrint('Profile sync was rejected: ${error.runtimeType}');
        await cache.setPendingChanges(true);
      }
    }
  }

  Future<void> clear() {
    _timer?.cancel();
    _timer = null;
    _latest = null;
    return cache.clear();
  }
}
