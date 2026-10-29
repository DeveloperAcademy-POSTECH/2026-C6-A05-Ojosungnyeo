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
        case nicknameSetup
        case authenticated
        case unauthenticated
    }

    @ObservableState
    struct State: Equatable {
        var authenticationStatus = AuthenticationStatus.checking
        var login = LoginFeature.State()
        var nicknameSetup = NicknameSetupFeature.State()
        var home = HomeFeature.State()
    }

    @CasePathable
    enum Action {
        case onAppear
        case authenticationStateChanged(AuthenticatedUser?)
        case nicknameStatusResponse(Result<Bool, Error>)
        case login(LoginFeature.Action)
        case nicknameSetup(NicknameSetupFeature.Action)
        case home(HomeFeature.Action)
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.nicknameClient) var nicknameClient

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

        Scope(state: \.nicknameSetup, action: \.nicknameSetup) {
            NicknameSetupFeature()
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
                guard let user else {
                    state.authenticationStatus = .unauthenticated
                    return .none
                }

                state.authenticationStatus = .checking
                state.nicknameSetup = NicknameSetupFeature.State(userID: user.id)
                return .run { send in
                    await send(
                        .nicknameStatusResponse(
                            Result {
                                try await nicknameClient.hasNickname(user.id)
                            }
                        )
                    )
                }

            case let .nicknameStatusResponse(.success(hasNickname)):
                state.authenticationStatus = hasNickname ? .authenticated : .nicknameSetup
                return .none

            case .nicknameStatusResponse(.failure):
                state.authenticationStatus = .nicknameSetup
                return .none

            case .login(.delegate(.signInSucceeded)):
                state.authenticationStatus = .checking
                return .none

            case .nicknameSetup(.delegate(.completed)):
                state.authenticationStatus = .authenticated
                return .none

            case .login, .nicknameSetup, .home:
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

            case .nicknameSetup:
                NicknameSetupView(
                    store: store.scope(
                        state: \.nicknameSetup,
                        action: \.nicknameSetup
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
