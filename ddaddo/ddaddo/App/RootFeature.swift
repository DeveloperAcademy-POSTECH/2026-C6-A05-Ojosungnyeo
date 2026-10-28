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
        var isAuthenticated = false
        var login = LoginFeature.State()
        var home = HomeFeature.State()
    }

    @CasePathable
    enum Action {
        case login(LoginFeature.Action)
        case home(HomeFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.login, action: \.login) {
            LoginFeature()
        }

        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case .login(.delegate(.signInSucceeded)):
                state.isAuthenticated = true
                return .none

            case .login, .home:
                return .none
            }
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        Group {
            if store.isAuthenticated {
                HomeView(
                    store: store.scope(
                        state: \.home,
                        action: \.home
                    )
                )
            } else {
                LoginView(
                    store: store.scope(
                        state: \.login,
                        action: \.login
                    )
                )
            }
        }
    }
}

#Preview {
    RootView(
        store: Store(initialState: RootFeature.State()) {
            RootFeature()
        }
    )
}
