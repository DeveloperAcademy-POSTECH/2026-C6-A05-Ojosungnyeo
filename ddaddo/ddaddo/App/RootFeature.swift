//
//  RootFeature.swift
//  ddaddo
//
//  Created by sun on 10/19/26.
//

import SwiftUI
import ComposableArchitecture

struct RootFeature: Reducer {
    enum AuthenticationStatus: Equatable {
        case checking
        case authenticated
        case unauthenticated
    }

    @ObservableState
    struct State: Equatable {
        var authenticationStatus = AuthenticationStatus.checking
        var login = LoginFeature.State()
        var home = HomeFeature.State()
    }

    @CasePathable
    enum Action {
        case onAppear
        case authenticationStateChanged(AuthenticatedUser?)
        case login(LoginFeature.Action)
        case home(HomeFeature.Action)
    }

    @Dependency(\.authClient) var authClient

    private nonisolated enum CancelID: Hashable, Sendable {
        case authenticationState
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
            case .onAppear:
                return .run { send in
                    for await user in await authClient.authStateChanges() {
                        await send(.authenticationStateChanged(user))
                    }
                }
                .cancellable(id: CancelID.authenticationState, cancelInFlight: true)

            case let .authenticationStateChanged(user):
                state.authenticationStatus = user == nil ? .unauthenticated : .authenticated
                return .none

            case .login(.delegate(.signInSucceeded)):
                state.authenticationStatus = .authenticated
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
            switch store.authenticationStatus {
            case .checking:
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }

            case .authenticated:
                HomeView(
                    store: store.scope(
                        state: \.home,
                        action: \.home
                    )
                )

            case .unauthenticated:
                LoginView(
                    store: store.scope(
                        state: \.login,
                        action: \.login
                    )
                )
            }
        }
        .task {
            store.send(.onAppear)
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
