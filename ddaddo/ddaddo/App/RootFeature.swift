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
        var transportationSelect = TransportationSelectFeature.State()
    }

    @CasePathable
    enum Action {
        case transportationSelect(TransportationSelectFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.transportationSelect, action: \.transportationSelect) {
            TransportationSelectFeature()
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        TransportationSelectView(
            store: store.scope(
                state: \.transportationSelect,
                action: \.transportationSelect
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
