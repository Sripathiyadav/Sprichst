import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/firebase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_errors.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

/// Sign-in progress and failure are tracked apart from the auth state itself,
/// so attempting to sign in never replaces the sign-in screen with a splash.
final signInInProgressProvider = StateProvider<bool>((ref) => false);
final signInErrorProvider = StateProvider<String?>((ref) => null);

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AsyncValue<User?>>(
  AuthViewModel.new,
);

class AuthViewModel extends Notifier<AsyncValue<User?>> {
  // Not final: `build` runs again whenever the repository provider changes.
  late AuthRepository _authRepository;

  @override
  AsyncValue<User?> build() {
    _authRepository = ref.watch(authRepositoryProvider);

    final subscription = _authRepository.authStateChanges.listen(
      (user) {
        state = AsyncData(user);
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );

    ref.onDispose(subscription.cancel);

    return AsyncData(_authRepository.currentUser);
  }

  /// Signs in with Google. The resulting user arrives through the auth-state
  /// stream; this only reports progress and failure.
  Future<void> signInWithGoogle() async {
    ref.read(signInErrorProvider.notifier).state = null;
    ref.read(signInInProgressProvider.notifier).state = true;

    try {
      await _authRepository.signInWithGoogle();
    } catch (error) {
      ref.read(signInErrorProvider.notifier).state = describeAuthError(error);
    } finally {
      ref.read(signInInProgressProvider.notifier).state = false;
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
  }

  Future<void> reauthenticateWithGoogle() {
    return _authRepository.reauthenticateWithGoogle();
  }

  Future<void> deleteCurrentUser() {
    return _authRepository.deleteCurrentUser();
  }
}
