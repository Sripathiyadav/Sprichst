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
