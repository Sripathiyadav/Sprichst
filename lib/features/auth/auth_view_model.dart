import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/firebase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AsyncValue<User?>>(
  AuthViewModel.new,
);

class AuthViewModel extends Notifier<AsyncValue<User?>> {
  late final AuthRepository _authRepository;

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

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();

    try {
      final credential = await _authRepository.signInWithGoogle();

      if (credential == null) {
        state = AsyncData(_authRepository.currentUser);
        return;
      }

      state = AsyncData(credential.user);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
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
