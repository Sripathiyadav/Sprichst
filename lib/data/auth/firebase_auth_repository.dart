import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialized;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<UserCredential?> signInWithGoogle() async {
    // Firebase handles Google authentication directly on Web.
    if (kIsWeb) {
      return _firebaseAuth.signInWithPopup(GoogleAuthProvider());
    }

    final credential = await _googleCredential();
    return credential == null
        ? null
        : _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('You need to be signed in to continue.');
    }

    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }

    final credential = await _googleCredential();
    if (credential == null) {
      throw const AuthCancelledException();
    }
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('You need to be signed in to delete this account.');
    }

    await user.delete();
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }

    await _firebaseAuth.signOut();
  }

  /// `google_sign_in` must be initialised exactly once: each call registers
  /// another platform event listener. A failed attempt is retried next time.
  Future<void> _ensureGoogleInitialized() {
    return _googleInitialized ??= _googleSignIn.initialize().catchError((
      Object error,
    ) {
      _googleInitialized = null;
      throw error;
    });
  }

  /// Runs the native Google flow and returns a Firebase credential, or null if
  /// the person dismissed the account chooser.
  Future<AuthCredential?> _googleCredential() async {
    await _ensureGoogleInitialized();

    try {
      final googleUser = await _googleSignIn.authenticate();
      return GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
