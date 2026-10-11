import 'package:flutter/material.dart';

/// Shown instead of a blank screen when the account service (Firebase) cannot
/// be started, for example a build made without its configuration.
class StartupProblemApp extends StatelessWidget {
  const StartupProblemApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Sprichst could not start',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'The sign-in service did not start. Check your internet '
                        'connection and open the app again. If you built the app '
                        'yourself, Firebase is not configured: see docs/SETUP.md.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
