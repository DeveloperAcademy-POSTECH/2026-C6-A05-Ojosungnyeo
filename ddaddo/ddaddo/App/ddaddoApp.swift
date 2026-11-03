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

    private let store: StoreOf<RootFeature>
    #if DEBUG
    private let debugTimeTableStore: StoreOf<TripItineraryFeature>
    #endif

    init() {
        GoogleMapsService.configure()
        FirebaseService.configure()
        store = Store(initialState: RootFeature.State()) {
            RootFeature()
        }
        #if DEBUG
        var debugState = TripItineraryFeature.State()
        debugState.selectedTab = .dailyItinerary
        debugState.timeTable = TimeTableFeature.debugEditPreviewState
        debugTimeTableStore = Store(initialState: debugState) {
            TripItineraryFeature()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-debugTimeTableEdit") {
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
