{{flutter_js}}
{{flutter_build_config}}

// Privacy: every resource comes from this origin.
//
// By default Flutter for web asks Google's servers for three things on every
// start-up, which tells Google the IP address of everyone who opens the app:
//   1. CanvasKit (the renderer)          -> www.gstatic.com/flutter-canvaskit
//   2. Roboto and fallback fonts         -> fonts.gstatic.com
//   3. The Firebase JavaScript SDK       -> www.gstatic.com/firebasejs
// The settings below serve all three from here instead. Roboto is bundled in
// pubspec.yaml, and the Firebase SDK is saved under web/vendor/firebasejs by
// scripts/vendor_web_deps.py. test/privacy_audit_test.dart keeps this honest.
(async function () {
  try {
    const base = new URL('vendor/firebasejs/', document.baseURI).href;
    // Load firebase-app.js first: the other bundles import it.
    window.firebase_core = await import(base + 'firebase-app.js');
    const [auth, firestore] = await Promise.all([
      import(base + 'firebase-auth.js'),
      import(base + 'firebase-firestore-pipelines.js'),
    ]);
    window.firebase_auth = auth;
    window.firebase_firestore = firestore;
  } catch (error) {
    // FlutterFire would now fall back to Google's CDN; make that visible.
    console.error('Could not load the bundled Firebase SDK from web/vendor.', error);
  }

  _flutter.loader.load({
    config: {
      canvasKitBaseUrl: 'canvaskit/',
      // Nothing is requested from fonts.gstatic.com for missing glyphs.
      fontFallbackBaseUrl: 'assets/fonts/fallback/',
    },
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
  });
})();
