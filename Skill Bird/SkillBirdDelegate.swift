import AdjustSdk
import AppTrackingTransparency
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

extension Notification.Name {
    static let birdFirebaseTokenReady = Notification.Name("birdFirebaseTokenReady")
    static let birdAttributionReady = Notification.Name("birdAttributionReady")
    static let aviaryPushOpened = Notification.Name("aviaryPushOpened")
    static let aviaryURLUpdated = Notification.Name("aviaryURLUpdated")
}

enum BirdLaunchVault {
    static let clientUUIDKey = "sbFlightInstallationID"
    static let serviceLinkKey = "sbFlightRoute"
    static let responseLinkKey = "sbFlightDestination"
    static let firebaseTokenKey = "sbMessagingToken"
    static let firebaseAppIDKey = "sbFirebaseApplicationID"
    static let pushIDKey = "sbPushMarker"
    static let pendingPushKey = "sbPushLaunchPending"
    static let adjustAttributionKey = "sbAdjustAttribution"

    static var clientUUID: String {
        if let saved = UserDefaults.standard.string(forKey: clientUUIDKey), !saved.isEmpty {
            return saved
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: clientUUIDKey)
        return value
    }

    static var firebaseToken: String? {
        nonEmpty(UserDefaults.standard.string(forKey: firebaseTokenKey))
    }

    static var adjustAttributionJSON: String? {
        nonEmpty(UserDefaults.standard.string(forKey: adjustAttributionKey))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

final class BirdAttributionObserver: NSObject, AdjustDelegate {
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        guard let attribution else { return }
        if #available(iOS 14, *),
           ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            return
        }
        guard let jsonResponse = attribution.jsonResponse,
              let data = try? JSONSerialization.data(withJSONObject: jsonResponse, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            UserDefaults.standard.removeObject(forKey: BirdLaunchVault.adjustAttributionKey)
            return
        }
        UserDefaults.standard.set(jsonString, forKey: BirdLaunchVault.adjustAttributionKey)
    }
}

final class SkillBirdDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    private let adjustAppToken = "51nsitg9eu80"
    private let attributionCollector = BirdAttributionObserver()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = BirdLaunchVault.clientUUID
        configureFirebase()
        configureAdjust()

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            savePushID(from: userInfo)
            UserDefaults.standard.set(true, forKey: BirdLaunchVault.pendingPushKey)
        }
        return true
    }

    private func configureAdjust() {
        let environment = ADJEnvironmentProduction
        guard let config = ADJConfig(appToken: adjustAppToken, environment: environment) else { return }
        config.delegate = attributionCollector
        config.logLevel = .info
        Adjust.initSdk(config)
    }

    private func configureFirebase() {
        FirebaseApp.configure()
        if let googleAppID = FirebaseApp.app()?.options.googleAppID,
           UserDefaults.standard.string(forKey: BirdLaunchVault.firebaseAppIDKey) != googleAppID {
            UserDefaults.standard.removeObject(forKey: BirdLaunchVault.firebaseTokenKey)
            UserDefaults.standard.set(googleAppID, forKey: BirdLaunchVault.firebaseAppIDKey)
        }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken sbMessagingToken: String?) {
        storeFirebaseToken(sbMessagingToken)
    }

    private func storeFirebaseToken(_ sbMessagingToken: String?) {
        guard let token = sbMessagingToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }
        UserDefaults.standard.set(token, forKey: BirdLaunchVault.firebaseTokenKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .birdFirebaseTokenReady, object: nil)
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                print("FCM token after APNS failed:", error.localizedDescription)
                return
            }
            self?.storeFirebaseToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNS registration failed:", error.localizedDescription)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(userInfo)
        savePushID(from: userInfo)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(userInfo)
        savePushID(from: userInfo)
        UserDefaults.standard.set(true, forKey: BirdLaunchVault.pendingPushKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .aviaryPushOpened, object: nil)
        }
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(userInfo)
        savePushID(from: userInfo)
        UserDefaults.standard.set(true, forKey: BirdLaunchVault.pendingPushKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .aviaryPushOpened, object: nil)
        }
        completionHandler(.newData)
    }

    private func savePushID(from userInfo: [AnyHashable: Any]) {
        if let pushID = extractPushID(from: userInfo) {
            UserDefaults.standard.set(pushID, forKey: BirdLaunchVault.pushIDKey)
        }
    }

    private func extractPushID(from object: Any) -> String? {
        if let dictionary = object as? [AnyHashable: Any] {
            for key in ["push_id", "gcm.notification.push_id"] {
                if let value = dictionary[key] {
                    let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { return text }
                }
            }
            for key in ["push_data", "data"] {
                if let nested = dictionary[key], let value = extractPushID(from: nested) { return value }
            }
        } else if let dictionary = object as? [String: Any] {
            return extractPushID(from: Dictionary(uniqueKeysWithValues: dictionary.map { (AnyHashable($0.key), $0.value) }))
        } else if let text = object as? String,
                  let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) {
            return extractPushID(from: json)
        }
        return nil
    }
}
