import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sprichst/features/auth/auth_errors.dart';

import 'support/fakes.dart';

Future<FakeAuthRepository> _openSignIn(
  WidgetTester tester, {
  Object? error,
}) async {
  final auth = FakeAuthRepository(signedIn: false, signInError: error);
  await pumpSprichst(tester,
      size: const Size(390, 844),
      brightness: Brightness.light,
      repository: InMemoryLearningRepository(),
      auth: auth);
  return auth;
}

void main() {
  group('describeAuthError', () {
    test('explains a misconfigured Google client', () {
      final message = describeAuthError(const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError));
      expect(message, contains('GoogleService-Info.plist'));
    });

    test('explains network and keychain failures plainly', () {
      expect(
          describeAuthError(
              FirebaseAuthException(code: 'network-request-failed')),
          contains('No connection'));
      expect(describeAuthError(FirebaseAuthException(code: 'keychain-error')),
          contains('Keychain Sharing'));
    });

    test('keeps the code for unknown Firebase errors and hides raw exceptions',
        () {
      expect(describeAuthError(FirebaseAuthException(code: 'weird-thing')),
          contains('weird-thing'));
      expect(describeAuthError(StateError('internal detail')),
          isNot(contains('internal detail')));
    });
  });

  testWidgets('a failed sign-in shows a friendly message and can be retried',
      (tester) async {
    final auth = await _openSignIn(tester,
        error: const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError));

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not configured'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget,
        reason: 'the sign-in screen stays; it is never swapped for a splash');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(auth.signInAttempts, 2);
  });

  testWidgets('dismissing the account chooser shows no error', (tester) async {
    await _openSignIn(tester); // the fake returns null, like a cancelled flow

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('failed'), findsNothing);
    expect(find.textContaining('not configured'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
