import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let pencilChannel = FlutterMethodChannel(
      name: "xournalpp/pencil",
      binaryMessenger: controller.binaryMessenger)

    pencilChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "enablePalmRejection":
        if #available(iOS 12.1, *) {
          controller.view.gestureRecognizers?.forEach { recognizer in
            if let recognizer = recognizer as? UIGestureRecognizer {
              recognizer.name = "flutter_gesture"
            }
          }
        }
        result(nil)
      case "getPressureSensitivity":
        result(1.0)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
