#!/usr/bin/env python3
"""Writes placeholder Firebase configuration so CI can compile the app.

The real `lib/firebase_options.dart` and `android/app/google-services.json` are
generated for your own Firebase project (`flutterfire configure`) and are not in
Git. Continuous integration only needs the code to compile and the tests to run
(they replace the Firebase services with fakes), so this script writes values
that look right and point nowhere. Never use the result for a real build.

    python3 scripts/ci_firebase_stub.py

It leaves existing files alone.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

OPTIONS = ROOT / "lib" / "firebase_options.dart"
SERVICES = ROOT / "android" / "app" / "google-services.json"

DART = """// Placeholder written by scripts/ci_firebase_stub.py. Not a real project.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const _options = FirebaseOptions(
    apiKey: 'ci-stub',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'ci-placeholder',
    authDomain: 'ci-placeholder.firebaseapp.com',
    storageBucket: 'ci-placeholder.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform => _options;
}
"""

SERVICES_JSON = {
    "project_info": {
        "project_number": "000000000000",
        "project_id": "ci-placeholder",
        "storage_bucket": "ci-placeholder.firebasestorage.app",
    },
    "client": [
        {
            "client_info": {
                "mobilesdk_app_id": "1:000000000000:android:0000000000000000",
                "android_client_info": {"package_name": "com.sprichst.app"},
            },
            "oauth_client": [],
            "api_key": [{"current_key": "ci-stub"}],
            "services": {"appinvite_service": {"other_platform_oauth_client": []}},
        }
    ],
    "configuration_version": "1",
}


def main() -> None:
    if not OPTIONS.exists():
        OPTIONS.write_text(DART)
        print("wrote", OPTIONS.relative_to(ROOT))
    if not SERVICES.exists():
        SERVICES.write_text(json.dumps(SERVICES_JSON, indent=2) + "\n")
        print("wrote", SERVICES.relative_to(ROOT))


if __name__ == "__main__":
    main()
