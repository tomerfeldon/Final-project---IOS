//
//  AppDelegate.swift
//  RunTracker
//

import UIKit
import FirebaseCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Properties

    /// Stays false when GoogleService-Info.plist is missing from the bundle.
    /// SceneDelegate reads this and shows a setup screen instead of letting the
    /// app crash somewhere deep inside Firestore.
    static var isFirebaseConfigured = false

    // MARK: - App Lifecycle

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureFirebase()
        return true
    }

    // MARK: - Firebase

    private func configureFirebase() {
        // FirebaseApp.configure() raises a fatal exception when the plist is
        // absent, so check first and fail with a readable message instead.
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("""
                  RunTracker: GoogleService-Info.plist was not found in the app bundle.
                  Download it from the Firebase console and drag it into the project.
                  See README.md, section "Firebase console setup".
                  """)
            return
        }

        FirebaseApp.configure()
        AppDelegate.isFirebaseConfigured = true
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration",
                                    sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
