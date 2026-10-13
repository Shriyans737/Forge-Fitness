import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let windowScene = scene as? UIWindowScene else { return }
    for window in windowScene.windows {
      window.backgroundColor = AppDelegate.launchBackgroundColor
      window.rootViewController?.view.backgroundColor = AppDelegate.launchBackgroundColor
    }
  }
}
