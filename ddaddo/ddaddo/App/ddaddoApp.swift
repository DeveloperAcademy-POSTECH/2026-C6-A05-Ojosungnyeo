//
//  ddaddoApp.swift
//  ddaddo
//
//  Created by sun on 10/18/26.
//

import SwiftUI
import ComposableArchitecture

@main
struct ddaddoApp: App {
    private let store: StoreOf<RootFeature>
    #if DEBUG
    private let debugTimeTableStore: StoreOf<TripItineraryFeature>
    #endif

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let isRunningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isTimeTableMock = arguments.contains("-timeTableMock")
        let isTimeTableEditMock = arguments.contains("-debugTimeTableEdit")
        if !isRunningForPreviews && !isTimeTableMock && !isTimeTableEditMock {
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
