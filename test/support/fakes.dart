import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/curriculum_parser.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/domain/repositories/auth_repository.dart';
import 'package:sprichst/domain/repositories/learning_repository.dart';
import 'package:sprichst/features/auth/auth_view_model.dart';

/// The real course file, parsed straight from disk (tests run from the root).
List<Lesson> loadCourse() =>
    CurriculumParser.parse(File('curriculum/course.json').readAsStringSync());

class FakeUser implements User {
  @override
  String get uid => 'test-user';

  @override
  String? get email => 'learner@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedIn = true});

  final bool signedIn;

  @override
  User? get currentUser => signedIn ? FakeUser() : null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<UserCredential?> signInWithGoogle() async => null;

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> signOut() async {}
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
  Future<List<Lesson>> loadLessons() async => loadCourse();
}

List<Override> testOverrides(InMemoryLearningRepository learning,
        {bool signedIn = true}) =>
    [
      authRepositoryProvider
          .overrideWithValue(FakeAuthRepository(signedIn: signedIn)),
      learningRepositoryProvider.overrideWithValue(learning),
      aiRepositoryProvider.overrideWithValue(MockAIRepository()),
    ];

/// Pumps the whole app at [size] with the platform in [brightness].
Future<void> pumpSprichst(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  required InMemoryLearningRepository repository,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: testOverrides(repository, signedIn: signedIn),
    child: const SprichstApp(),
  ));
  await tester.pumpAndSettle();
}
