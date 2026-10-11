import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Turns a sign-in failure into a message a learner can act on. The raw error
/// code is kept at the end so a bug report still carries what went wrong.
String describeAuthError(Object error) {
  return switch (error) {
    GoogleSignInException(:final code) => switch (code) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google sign-in is not configured for this build. On iOS check GoogleService-Info.plist and the URL scheme; on Android add this build\'s SHA-1 to the Firebase app and download google-services.json again.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in could not start on this device. Check your internet connection and that Keychain access is allowed, then try again.',
        GoogleSignInExceptionCode.unknownError =>
          'Google sign-in did not complete. Check your connection and that a Google account is added on this device (on an emulator: Settings → Passwords & accounts), then try again.',
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
