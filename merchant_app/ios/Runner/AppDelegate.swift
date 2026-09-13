import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard
      let mapsApiKey = Bundle.main.object(
        forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY"
      ) as? String,
      !mapsApiKey.isEmpty,
      !mapsApiKey.contains("$(")
    else {
      fatalError("GOOGLE_MAPS_API_KEY is missing")
    }

    GMSServices.provideAPIKey(mapsApiKey)

    GeneratedPluginRegistrant.register(with: self)

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }
}
