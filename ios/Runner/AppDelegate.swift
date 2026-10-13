import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static let launchBackgroundColor: UIColor = {
    let hex = (Bundle.main.object(forInfoDictionaryKey: "ForgeLaunchBackgroundColor") as? String)?
      .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard let hex, hex.count == 6, let value = UInt32(hex, radix: 16) else {
      return UIColor(red: 7 / 255, green: 12 / 255, blue: 11 / 255, alpha: 1)
    }
    return UIColor(
      red: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
    )
  }()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    window?.backgroundColor = Self.launchBackgroundColor
    window?.rootViewController?.view.backgroundColor = Self.launchBackgroundColor
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
