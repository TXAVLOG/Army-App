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
    return result
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
