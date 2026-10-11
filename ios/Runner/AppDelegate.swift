import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeModelsFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// On-device AI models (0.5–2.5 GB) can be downloaded again, so Apple's
  /// storage guidelines require keeping them out of iCloud backups. Marking
  /// the folder covers everything later saved inside it.
  private func excludeModelsFromBackup() {
    guard var models = FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent("models", isDirectory: true)
    else { return }
    try? FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? models.setResourceValues(values)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
