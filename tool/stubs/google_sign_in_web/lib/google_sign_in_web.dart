import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Does nothing on purpose.
///
/// The real plugin loads `https://accounts.google.com/gsi/client` the moment the
/// app starts, which sends the IP address of every visitor to Google even if
/// they never sign in. On the web Sprichst signs in with Firebase's own popup
/// (`FirebaseAuth.signInWithPopup`), which only contacts Google when the person
/// presses "Continue with Google". `google_sign_in` is used on Android and iOS,
/// where this web plugin is not involved.
class GoogleSignInPlugin {
  static void registerWith(Registrar registrar) {
    // Intentionally not registered: nothing on the web uses google_sign_in.
  }
}
