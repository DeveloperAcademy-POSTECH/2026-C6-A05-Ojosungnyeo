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

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
