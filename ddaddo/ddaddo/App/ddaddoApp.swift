//
//  ddaddoApp.swift
//  ddaddo
//
//  Created by sun on 10/18/26.
//

import SwiftUI
import ComposableArchitecture
import FirebaseAuth
import FirebaseMessaging
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate,
    MessagingDelegate {
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-timeTableMock") || arguments.contains("-debugTimeTableEdit") {
            return true
        }
        #endif
        FirebaseService.configure()
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        authStateHandle = Auth.auth().addStateDidChangeListener { _, user in
            guard user != nil else { return }
            Messaging.messaging().register { _ in }
        }
        Task {
            _ = await LocalNotificationService.requestAuthorization()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistration installationID: String?) {
        guard let installationID else { return }
        Task {
            try? await FirebasePushNotificationService.saveRegistrationID(installationID)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct ddaddoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let store: StoreOf<RootFeature>
    #if DEBUG
    private let debugTimeTableStore: StoreOf<TripItineraryFeature>
    #endif

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let isTimeTableMock = arguments.contains("-timeTableMock")
        let isTimeTableEditMock = arguments.contains("-debugTimeTableEdit")
        if !isTimeTableMock && !isTimeTableEditMock {
            GoogleMapsService.configure()
            FirebaseService.configure()
        }
        #else
        GoogleMapsService.configure()
        FirebaseService.configure()
        #endif
        store = Store(initialState: RootFeature.State()) {
            RootFeature()
        }
        #if DEBUG
        var debugState = TripItineraryFeature.State()
        debugState.selectedTab = .dailyItinerary
        debugState.timeTable = isTimeTableMock
            ? TimeTableFeature.debugMockState
            : TimeTableFeature.debugEditPreviewState
        debugTimeTableStore = Store(initialState: debugState) {
            TripItineraryFeature()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-timeTableMock") ||
                ProcessInfo.processInfo.arguments.contains("-debugTimeTableEdit") {
                TripItineraryView(store: debugTimeTableStore)
            } else {
                RootView(store: store)
            }
            #else
            RootView(store: store)
            #endif
        }
    }
}
