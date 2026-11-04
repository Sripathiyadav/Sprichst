import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/domain/repositories/auth_repository.dart';
import 'package:sprichst/features/account/account_view.dart';

import 'support/fakes.dart';

/// An account service the test signs in to by hand.
class _Auth implements AuthRepository {
  _Auth({this.signInError});

  final Object? signInError;
  final _changes = StreamController<User?>.broadcast();
  User? _user;

  void signIn() => _changes.add(_user = FakeUser());

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get authStateChanges => _changes.stream;

  @override
  Future<UserCredential?> signInWithGoogle() async {
    if (signInError != null) throw signInError!;
    signIn();
    return null;
  }

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> signOut() async => _changes.add(_user = null);

  @override
  Future<String?> idToken() async => null;
}

LearningProfile _learner(String name, {int xp = 0}) =>
    LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.a1)
        .copyWith(name: name, xp: xp);

const _guestOn = {'sprichst_guest_v1': true};

Future<void> _pump(
  WidgetTester tester, {
  required InMemoryLearningRepository account,
  required InMemoryLearningRepository guest,
  required AuthRepository auth,
  Map<String, Object> storage = const {},
}) =>
    pumpSprichst(tester,
        size: const Size(390, 844),
        brightness: Brightness.light,
        repository: account,
        guest: guest,
        auth: auth,
        storage: storage);

void main() {
  testWidgets('a learner can start without an account', (tester) async {
    final guest = InMemoryLearningRepository();
    await _pump(tester,
        account: InMemoryLearningRepository(), guest: guest, auth: _Auth());

    expect(find.textContaining('stays on this device only'), findsOneWidget);
    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();

    // Straight into onboarding, with nothing asked of an account.
    expect(find.text('Continue without an account'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('a returning guest opens Home with a way to sync',
      (tester) async {
    await _pump(tester,
        account: InMemoryLearningRepository(),
        guest: InMemoryLearningRepository(_learner('Mia')),
        auth: _Auth(),
        storage: _guestOn);

    expect(find.textContaining('Mia'), findsWidgets);
    expect(find.byKey(const ValueKey('home-guest-sync')), findsOneWidget);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-guest-sync')), findsNothing);
  });

  testWidgets('signing in moves guest progress to an empty account',
      (tester) async {
    final account = InMemoryLearningRepository();
    final guest = InMemoryLearningRepository(_learner('Mia', xp: 40));
    await _pump(tester,
        account: account, guest: guest, auth: _Auth(), storage: _guestOn);

    await tester.tap(find.text('Sign in to sync'));
    await tester.pumpAndSettle();

    expect(account.profile?.xp, 40);
    expect(guest.profile, isNull);
    expect(find.byKey(const ValueKey('home-guest-sync')), findsNothing);
    expect(find.textContaining('Mia'), findsWidgets);
  });

  testWidgets('when both have progress the learner chooses', (tester) async {
    final account = InMemoryLearningRepository(_learner('Konto', xp: 90));
    final guest = InMemoryLearningRepository(_learner('Mia', xp: 40));
    await _pump(tester,
        account: account, guest: guest, auth: _Auth(), storage: _guestOn);

    await tester.tap(find.text('Sign in to sync'));
    await tester.pumpAndSettle();

    expect(find.text('Which progress should we keep?'), findsOneWidget);
    // Nothing is replaced before the choice.
    expect(account.profile?.xp, 90);
    expect(guest.profile?.xp, 40);

    await tester.tap(find.byKey(const ValueKey('keep-device')));
    await tester.pumpAndSettle();
    expect(account.profile?.xp, 40);
    expect(guest.profile, isNull);
  });

  testWidgets('keeping the account progress leaves it as it was',
      (tester) async {
    final account = InMemoryLearningRepository(_learner('Konto', xp: 90));
    final guest = InMemoryLearningRepository(_learner('Mia', xp: 40));
    await _pump(tester,
        account: account, guest: guest, auth: _Auth(), storage: _guestOn);

    await tester.tap(find.text('Sign in to sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keep-account')));
    await tester.pumpAndSettle();

    expect(account.profile?.xp, 90);
    expect(guest.profile, isNull);
    expect(find.textContaining('Konto'), findsWidgets);
  });

  testWidgets('a cancelled sign-in keeps the guest where they were',
      (tester) async {
    final guest = InMemoryLearningRepository(_learner('Mia', xp: 40));
    await _pump(tester,
        account: InMemoryLearningRepository(),
        guest: guest,
        auth: _Auth(signInError: const AuthCancelledException()),
        storage: _guestOn);

    await tester.tap(find.text('Sign in to sync'));
    await tester.pumpAndSettle();

    expect(guest.profile?.xp, 40);
    expect(find.byKey(const ValueKey('home-guest-sync')), findsOneWidget);
  });

  testWidgets('a guest can erase the progress on this device', (tester) async {
    final guest = InMemoryLearningRepository(_learner('Mia'));
    await _pump(tester,
        account: InMemoryLearningRepository(),
        guest: guest,
        auth: _Auth(),
        storage: _guestOn);

    await tester.tap(find.byKey(const ValueKey('home-account')));
    await tester.pumpAndSettle();
    expect(find.text('Delete account'), findsNothing);
    expect(find.text('Sign out'), findsNothing);

    final erase = find.text('Erase progress on this device');
    await tester.scrollUntilVisible(erase, 200,
        scrollable: find
            .descendant(
                of: find.byType(AccountView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(erase);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();

    expect(guest.profile, isNull);
    expect(find.text('Continue without an account'), findsOneWidget);
  });
}
