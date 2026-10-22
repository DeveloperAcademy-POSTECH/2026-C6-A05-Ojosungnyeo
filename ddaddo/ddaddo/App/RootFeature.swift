//
//  RootFeature.swift
//  ddaddo
//
//  Created by sun on 10/19/26.
//

import SwiftUI
import ComposableArchitecture

struct RootFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var tripItinerary = TripItineraryFeature.State()
    }

    @CasePathable
    enum Action {
        case tripItinerary(TripItineraryFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.tripItinerary, action: \.tripItinerary) {
            TripItineraryFeature()
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        TripItineraryView(
            store: store.scope(
                state: \.tripItinerary,
                action: \.tripItinerary
            )
        )
    }
}

#Preview {
    RootView(
        store: Store(initialState: RootFeature.State()) {
            RootFeature()
        }
    )
}
