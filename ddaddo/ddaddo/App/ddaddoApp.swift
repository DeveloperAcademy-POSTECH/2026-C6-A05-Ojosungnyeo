//
//  ddaddoApp.swift
//  ddaddo
//
//  Created by sun on 10/18/26.
//

import SwiftUI
import ComposableArchitecture
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseService.configure()
        return true
    }
}

@main
struct ddaddoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let store = Store(initialState: RootFeature.State()) {
        RootFeature()
    }

    init() {
        GoogleMapsService.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
