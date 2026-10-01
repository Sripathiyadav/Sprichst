import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;

  User? get currentUser;

  Future<UserCredential?> signInWithGoogle();

  Future<void> signOut();
}
