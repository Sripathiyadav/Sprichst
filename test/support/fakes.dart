import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/cloud_ai_settings.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/curriculum_parser.dart';
import 'package:sprichst/domain/models/dialogue_models.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/domain/repositories/auth_repository.dart';
import 'package:sprichst/domain/repositories/learning_repository.dart';
import 'package:sprichst/features/auth/auth_view_model.dart';

import 'on_device_fakes.dart';

/// The real course file, parsed straight from disk (tests run from the root).
List<Lesson> loadCourse() =>
    CurriculumParser.parse(File('curriculum/course.json').readAsStringSync());

List<Dialogue> loadCourseDialogues() => CurriculumParser.parseDialogues(
    File('curriculum/course.json').readAsStringSync());

class FakeUser implements User {
  @override
  String get uid => 'test-user';

  @override
  String? get email => 'learner@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedIn = true, this.signInError});

  final bool signedIn;

  /// When set, [signInWithGoogle] throws it.
  final Object? signInError;
  var signInAttempts = 0;

  @override
  User? get currentUser => signedIn ? FakeUser() : null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<UserCredential?> signInWithGoogle() async {
    signInAttempts++;
    if (signInError != null) throw signInError!;
    return null;
  }

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;
}

class InMemoryLearningRepository implements LearningRepository {
  InMemoryLearningRepository([this.profile]);

  LearningProfile? profile;

  @override
  Future<LearningProfile?> loadProfile() async => profile;

  @override
  Future<void> saveProfile(LearningProfile profile) async =>
      this.profile = profile;

  @override
  Future<void> deleteLearningData() async => profile = null;

  @override
  Future<void> flush() async {}

  @override
  Future<List<Lesson>> loadLessons() async => loadCourse();

  @override
  Future<List<Dialogue>> loadDialogues() async => loadCourseDialogues();
}

List<Override> testOverrides(InMemoryLearningRepository learning,
        {bool signedIn = true,
        FakeAuthRepository? auth,
        List<Override> extra = const []}) =>
    [
      authRepositoryProvider
          .overrideWithValue(auth ?? FakeAuthRepository(signedIn: signedIn)),
      learningRepositoryProvider.overrideWithValue(learning),
      aiRepositoryProvider.overrideWithValue(MockAIRepository()),
      onDeviceRuntimeProvider.overrideWithValue(FakeRuntime()),
      cloudAISettingsProvider
          .overrideWith((ref) => CloudAISettings(store: MemorySecretStore())),
      ...extra,
    ];

/// A secret store that lives in memory, so no platform plugin is needed.
class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;
  var failWrites = false;

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async {
    if (failWrites) throw StateError('locked');
    values[name] = value;
  }

  @override
  Future<void> delete(String name) async => values.remove(name);
}

/// Pumps the whole app at [size] with the platform in [brightness].
Future<void> pumpSprichst(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  required InMemoryLearningRepository repository,
  bool signedIn = true,
  FakeAuthRepository? auth,
  double textScale = 1,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  // The Coach screen creates a recorder; there is no microphone under test.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    (_) async => null,
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      null,
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: testOverrides(repository,
        signedIn: signedIn, auth: auth, extra: extraOverrides),
    child: const SprichstApp(),
  ));
  await tester.pumpAndSettle();
}
