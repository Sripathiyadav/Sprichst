import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;

  User? get currentUser;

  Future<UserCredential?> signInWithGoogle();

  /// Refreshes the sign-in before an irreversible account action.
  Future<void> reauthenticateWithGoogle();

  Future<void> deleteCurrentUser();

  Future<void> signOut();
}

/// Thrown when someone dismisses a sign-in prompt that an action depends on.
class AuthCancelledException implements Exception {
  const AuthCancelledException();

  @override
  String toString() => 'Sign-in was cancelled.';
}
