import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'app/app.dart';
import 'app/startup_problem.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Nothing works without the account service; say so instead of showing a
    // blank screen. The cause is not shown: it can name project settings.
    runApp(const StartupProblemApp());
    return;
  }

  runApp(const ProviderScope(child: SprichstApp()));
}
