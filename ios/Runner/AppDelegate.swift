import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureField: UITextField?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    makeSecureWindow()

    if let controller = window?.rootViewController as? FlutterViewController {
      let iconChannel = FlutterMethodChannel(name: "vn.army.txa/app_icon", binaryMessenger: controller.binaryMessenger)
      iconChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "changeAppIcon" {
          if let args = call.arguments as? [String: Any],
             let iconName = args["iconName"] as? String {
            self?.changeAppIcon(iconName: iconName, result: result)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Arguments must contain iconName", details: nil))
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }

    return result
  }

  private func changeAppIcon(iconName: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "NOT_SUPPORTED", message: "iOS device does not support alternate icons", details: nil))
        return
      }
      
      let targetIconName: String? = (iconName == "default_gold" || iconName.isEmpty) ? nil : iconName
      
      UIApplication.shared.setAlternateIconName(targetIconName) { error in
        if let error = error {
          result(FlutterError(code: "ICON_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(true)
        }
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func makeSecureWindow() {
    DispatchQueue.main.async {
      if self.secureField == nil {
        let field = UITextField()
        field.isSecureTextEntry = true
        self.secureField = field
        
        if let window = UIApplication.shared.windows.first {
          if let secureLayoutView = field.subviews.first {
            window.addSubview(secureLayoutView)
            secureLayoutView.topAnchor.constraint(equalTo: window.topAnchor).isActive = true
            secureLayoutView.bottomAnchor.constraint(equalTo: window.bottomAnchor).isActive = true
            secureLayoutView.leadingAnchor.constraint(equalTo: window.leadingAnchor).isActive = true
            secureLayoutView.trailingAnchor.constraint(equalTo: window.trailingAnchor).isActive = true
          }
        }
      }
    }
  }
}
