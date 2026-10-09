import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;

  User? get currentUser;

  Future<UserCredential?> signInWithGoogle();

  /// Refreshes the sign-in before an irreversible account action.
  Future<void> reauthenticateWithGoogle();

  Future<void> deleteCurrentUser();

  Future<void> signOut();

  /// A fresh Firebase ID token for the signed-in learner, or null when signed
  /// out. Sent to the AI server so it can tell real learners from strangers.
  Future<String?> idToken();
}

/// Thrown when someone dismisses a sign-in prompt that an action depends on.
class AuthCancelledException implements Exception {
  const AuthCancelledException();

  @override
  String toString() => 'Sign-in was cancelled.';
}
