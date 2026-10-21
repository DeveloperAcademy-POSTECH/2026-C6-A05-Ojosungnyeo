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
        var placeSelection = PlaceSelectionFeature.State()
    }

    @CasePathable
    enum Action {
        case placeSelection(PlaceSelectionFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.placeSelection, action: \.placeSelection) {
            PlaceSelectionFeature()
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        PlaceSelectionView(
            store: store.scope(
                state: \.placeSelection,
                action: \.placeSelection
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
