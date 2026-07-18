//
//  SceneDelegate.swift
//  RunTracker
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // MARK: - Properties

    var window: UIWindow?

    // MARK: - Scene Lifecycle

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard (scene as? UIWindowScene) != nil else { return }

        // The window and its root controller already come from Main.storyboard.
        // Swap the root out only when Firebase could not be configured, so the
        // first thing the user sees explains what to do rather than crashing.
        if !AppDelegate.isFirebaseConfigured {
            window?.rootViewController = SetupRequiredController()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
