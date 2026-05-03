import UIKit
import SwiftUI

// Phase 4b — minimal AppDelegate just to bridge APNs registration callbacks
// from UIKit into PushService. SwiftUI uses @UIApplicationDelegateAdaptor in
// LoverApp.swift to install this.

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            PushService.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
}
