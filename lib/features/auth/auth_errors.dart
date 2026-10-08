import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Turns a sign-in failure into a message a learner can act on. The raw error
/// code is kept at the end so a bug report still carries what went wrong.
String describeAuthError(Object error) {
  return switch (error) {
    GoogleSignInException(:final code) => switch (code) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google sign-in is not configured for this build. Check the iOS GoogleService-Info.plist and URL scheme.',
        GoogleSignInExceptionCode.interrupted =>
          'Sign-in was interrupted. Please try again.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google sign-in could not open. Please try again.',
        _ => 'Google sign-in failed (${code.name}).',
      },
    FirebaseAuthException(:final code) => switch (code) {
        'network-request-failed' =>
          'No connection. Check your internet and try again.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' =>
          'Too many attempts. Please wait a moment and try again.',
        'keychain-error' =>
          'Secure storage is unavailable. On a simulator, enable Keychain Sharing for the Runner target.',
        'account-exists-with-different-credential' =>
          'An account already exists with this email using another sign-in method.',
        _ => 'Sign-in failed ($code).',
      },
    _ => 'Sign-in failed. Please try again.',
  };
}
