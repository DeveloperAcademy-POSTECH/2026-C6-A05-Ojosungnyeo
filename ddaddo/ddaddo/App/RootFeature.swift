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
        var home = HomeFeature.State()
    }

    @CasePathable
    enum Action {
        case home(HomeFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        HomeView(
            store: store.scope(
                state: \.home,
                action: \.home
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
