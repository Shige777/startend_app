import Flutter
import UIKit
import GoogleSignIn
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase初期化
    FirebaseApp.configure()
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Google Sign-In設定
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: path),
       let clientId = plist["CLIENT_ID"] as? String {
      print("iOS: Setting up Google Sign-In with Client ID: \(clientId)")
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
      print("iOS: Google Sign-In configuration set successfully")
    } else {
      print("iOS: Failed to load GoogleService-Info.plist or CLIENT_ID")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
