//
//  LocalNotificationService.swift
//  ddaddo
//

import UserNotifications

@MainActor
enum LocalNotificationService {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

}
