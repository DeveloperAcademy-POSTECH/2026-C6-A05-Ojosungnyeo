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
    private let store = Store(initialState: RootFeature.State()) {
        RootFeature()
    }

    init() {
        GoogleMapsService.configure()
    }

    var body: some Scene {
        WindowGroup {
            //RootView(store: store)
            TripSearchView(
                        store: Store(initialState: TripSearchFeature.State()) {
                            TripSearchFeature()
                        }
                    )
        }
    }
}
