import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprichst/app/startup_problem.dart';
import 'package:sprichst/data/profile_sync.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/models/learning_models.dart';

class _Offline implements Exception {}

class _Rejected implements Exception {}

class _MemoryCache implements ProfileCache {
  LearningProfile? profile;
  bool pending = false;

  @override
  Future<LearningProfile?> load() async => profile;
  @override
  Future<void> save(LearningProfile p) async => profile = p;
  @override
  Future<bool> hasPendingChanges() async => pending;
  @override
  Future<void> setPendingChanges(bool value) async => pending = value;
  @override
  Future<void> clear() async {
    profile = null;
    pending = false;
  }
}

LearningProfile _profile(int xp) => LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.a1)
    .copyWith(xp: xp);

class _Cloud {
  LearningProfile? stored;
  var online = true;
  var rejects = false;
  var saves = 0;

  SyncedProfileStore store(ProfileCache cache,
          {Duration delay = Duration.zero}) =>
      SyncedProfileStore(
        delay: delay,
        cache: cache,
        loadRemote: () async {
          if (!online) throw _Offline();
          return stored;
        },
        saveRemote: (p) async {
          if (!online) throw _Offline();
          if (rejects) throw _Rejected();
          saves++;
          stored = p;
        },
        isUnreachable: (e) => e is _Offline,
      );
}

void main() {
  late _MemoryCache cache;
  late _Cloud cloud;

  setUp(() {
    cache = _MemoryCache();
    cloud = _Cloud();
  });

  group('loading', () {
    test('the cloud wins and refreshes the device copy', () async {
      cloud.stored = _profile(50);
      cache.profile = _profile(10);
      expect((await cloud.store(cache).load())!.xp, 50);
      expect(cache.profile!.xp, 50);
    });

    test('a new account has no profile', () async {
      expect(await cloud.store(cache).load(), isNull);
    });

    test('offline, the device copy is used', () async {
      cache.profile = _profile(30);
      cloud.online = false;
      expect((await cloud.store(cache).load())!.xp, 30);
    });

    test('offline with nothing saved on the device is an error', () async {
      cloud.online = false;
      expect(cloud.store(cache).load(), throwsA(isA<_Offline>()));
    });

    test('other failures are not hidden by the cache', () async {
      cache.profile = _profile(30);
      final store = SyncedProfileStore(
        cache: cache,
        loadRemote: () async => throw StateError('permission denied'),
        saveRemote: (_) async {},
        isUnreachable: (e) => e is _Offline,
      );
      expect(store.load(), throwsStateError);
    });
  });

  group('saving', () {
    test('lands on the device and in the cloud', () async {
      await cloud.store(cache).save(_profile(5));
      expect(cache.profile!.xp, 5);
      expect(cloud.stored!.xp, 5);
      expect(cache.pending, isFalse);
    });

    test('offline it is kept and flagged, not lost', () async {
      cloud.online = false;
      await cloud.store(cache).save(_profile(7));
      expect(cache.profile!.xp, 7);
      expect(cache.pending, isTrue);
      expect(cloud.stored, isNull);
    });

    test('a rejected write is an error, not a silent pending change', () async {
      cloud.rejects = true;
      await expectLater(
          cloud.store(cache).save(_profile(7)), throwsA(isA<_Rejected>()));
      expect(cache.pending, isFalse);
    });
  });

  group('gathering writes to save the free quota', () {
    const delay = Duration(seconds: 8);

    test('a burst of changes becomes one cloud write with the latest data', () {
      fakeAsync((async) {
        final sync = cloud.store(cache, delay: delay);
        for (final xp in [1, 2, 3]) {
          sync.save(_profile(xp));
          async.elapse(const Duration(seconds: 2));
        }
        async.flushMicrotasks();
        expect(cloud.saves, 0, reason: 'still waiting for more changes');
        expect(cache.profile!.xp, 3, reason: 'but safe on the device at once');
        expect(cache.pending, isTrue);

        async.elapse(delay);
        async.flushMicrotasks();
        expect(cloud.saves, 1);
        expect(cloud.stored!.xp, 3);
        expect(cache.pending, isFalse);
      });
    });

    test('flush sends it straight away', () {
      fakeAsync((async) {
        final sync = cloud.store(cache, delay: delay);
        sync.save(_profile(4));
        async.flushMicrotasks();
        sync.flush();
        async.flushMicrotasks();
        expect(cloud.stored!.xp, 4);
        expect(cache.pending, isFalse);

        async.elapse(delay * 2);
        async.flushMicrotasks();
        expect(cloud.saves, 1, reason: 'the timer must not write it again');
      });
    });

    test('flush with nothing waiting does nothing', () {
      fakeAsync((async) {
        cloud.store(cache, delay: delay).flush();
        async.flushMicrotasks();
        expect(cloud.saves, 0);
      });
    });

    test('an app killed before the write leaves it flagged for the next start',
        () async {
      final first = cloud.store(cache, delay: delay);
      await first.save(_profile(6)); // the timer never fires: the app is gone
      expect(cache.pending, isTrue);
      expect(cloud.stored, isNull);

      final next = await cloud.store(cache, delay: delay).load();
      expect(next!.xp, 6);
      expect(cloud.stored!.xp, 6);
      expect(cache.pending, isFalse);
    });

    test('a write the cloud rejects in the background stays pending', () {
      fakeAsync((async) {
        cloud.rejects = true;
        final sync = cloud.store(cache, delay: delay);
        sync.save(_profile(8));
        async.elapse(delay);
        async.flushMicrotasks();
        expect(cache.pending, isTrue);
        expect(cloud.stored, isNull);
      });
    });

    test('clearing cancels a write that was waiting', () {
      fakeAsync((async) {
        final sync = cloud.store(cache, delay: delay);
        sync.save(_profile(9));
        async.flushMicrotasks();
        sync.clear();
        async.elapse(delay * 2);
        async.flushMicrotasks();
        expect(cloud.saves, 0);
        expect(cache.profile, isNull);
      });
    });
  });

  group('catching up', () {
    test('pending offline work is pushed on the next load and beats the cloud',
        () async {
      cloud.stored = _profile(10); // older, from before the offline session
      cloud.online = false;
      await cloud.store(cache).save(_profile(40));

      cloud.online = true;
      final loaded = await cloud.store(cache).load();
      expect(loaded!.xp, 40);
      expect(cloud.stored!.xp, 40);
      expect(cache.pending, isFalse);
    });

    test('still offline, pending work stays pending and usable', () async {
      cloud.online = false;
      await cloud.store(cache).save(_profile(40));
      expect((await cloud.store(cache).load())!.xp, 40);
      expect(cache.pending, isTrue);
    });

    test('a flag with no saved profile is dropped', () async {
      cache.pending = true;
      cloud.stored = _profile(3);
      expect((await cloud.store(cache).load())!.xp, 3);
      expect(cache.pending, isFalse);
    });

    test('clearing removes the copy and the flag', () async {
      cloud.online = false;
      await cloud.store(cache).save(_profile(9));
      await cloud.store(cache).clear();
      expect(cache.profile, isNull);
      expect(cache.pending, isFalse);
    });
  });

  group('the device cache', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps each account separate and round-trips a profile', () async {
      final a = SharedPrefsProfileCache('alice');
      final b = SharedPrefsProfileCache('bob');
      await a.save(_profile(12));
      expect((await a.load())!.xp, 12);
      expect(await b.load(), isNull);
      await a.setPendingChanges(true);
      expect(await a.hasPendingChanges(), isTrue);
      expect(await b.hasPendingChanges(), isFalse);
      await a.clear();
      expect(await a.load(), isNull);
      expect(await a.hasPendingChanges(), isFalse);
    });

    test('a damaged copy reads as empty', () async {
      SharedPreferences.setMockInitialValues(
          {'sprichst_profile_cache_v1_x': '{not json'});
      expect(await SharedPrefsProfileCache('x').load(), isNull);
    });
  });

  testWidgets('a failed start explains itself instead of showing nothing',
      (tester) async {
    await tester.pumpWidget(const StartupProblemApp());
    expect(find.text('Sprichst could not start'), findsOneWidget);
    expect(find.textContaining('docs/SETUP.md'), findsOneWidget);
  });

  test('a cloze exercise with no blanks scores a number, not NaN', () {
    const exercise = Exercise(
      id: 'c',
      prompt: 'p',
      answer: '',
      explanation: 'e',
      skills: ['s'],
      kind: ExerciseKind.cloze,
    );
    final result = const ExerciseEvaluator().evaluate(exercise, '');
    expect(result.score.isNaN, isFalse);
    expect(result.score, 1.0);
  });
}
