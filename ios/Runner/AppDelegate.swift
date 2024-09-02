import UIKit
import Flutter
import flutter_background_service_ios // Import the background service plugin

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set the custom task identifier for the background service
    SwiftFlutterBackgroundServicePlugin.taskIdentifier = "your.custom.task.identifier"
    
    // Register the plugin with Flutter
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
