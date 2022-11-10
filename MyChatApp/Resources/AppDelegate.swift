//
//  AppDelegate.swift
//  MyChatApp
//
//  Created by Андрей on 28.10.2022.
//

import UIKit
import FirebaseCore
import FBSDKCoreKit
import GoogleSignIn

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        FirebaseApp.configure()
        
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        return true
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(
            application,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
        
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {

    }
}
