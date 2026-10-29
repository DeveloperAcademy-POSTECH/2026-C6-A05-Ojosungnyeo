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
        case nicknameCheckFailed
        case nicknameSetup
        case authenticated
        case unauthenticated
    }

    @ObservableState
    struct State: Equatable {
        var authenticationStatus = AuthenticationStatus.checking
        var authenticatedUserID: String?
        var login = LoginFeature.State()
        var nicknameSetup = NicknameSetupFeature.State()
        var home = HomeFeature.State()
    }

    @CasePathable
    enum Action {
        case onAppear
        case authenticationStateChanged(AuthenticatedUser?)
        case nicknameStatusResponse(userID: String, Result<Bool, Error>)
        case nicknameStatusRetryButtonTapped
        case login(LoginFeature.Action)
        case nicknameSetup(NicknameSetupFeature.Action)
        case home(HomeFeature.Action)
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.nicknameClient) var nicknameClient

    private nonisolated enum CancelID: Hashable, Sendable {
        case authenticationState
        case nicknameStatus
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
                    state.authenticatedUserID = nil
                    state.authenticationStatus = .unauthenticated
                    return .none
                }

                state.authenticatedUserID = user.id
                state.authenticationStatus = .checking
                state.nicknameSetup = NicknameSetupFeature.State(userID: user.id)
                return checkNickname(userID: user.id)

            case let .nicknameStatusResponse(userID, .success(hasNickname)):
                guard state.authenticatedUserID == userID else { return .none }
                state.authenticationStatus = hasNickname ? .authenticated : .nicknameSetup
                return .none

            case let .nicknameStatusResponse(userID, .failure):
                guard state.authenticatedUserID == userID else { return .none }
                state.authenticationStatus = .nicknameCheckFailed
                return .none

            case .nicknameStatusRetryButtonTapped:
                guard let userID = state.authenticatedUserID else {
                    state.authenticationStatus = .unauthenticated
                    return .none
                }
                state.authenticationStatus = .checking
                return checkNickname(userID: userID)

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

    private func checkNickname(userID: String) -> Effect<Action> {
        .run { send in
            await send(
                .nicknameStatusResponse(
                    userID: userID,
                    Result {
                        try await nicknameClient.hasNickname(userID)
                    }
                )
            )
        }
        .cancellable(id: CancelID.nicknameStatus, cancelInFlight: true)
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

            case .nicknameCheckFailed:
                VStack(spacing: 20) {
                    Text("닉네임 정보를 불러오지 못했어요.")
                        .foregroundStyle(.white)

                    Button("다시 시도") {
                        store.send(.nicknameStatusRetryButtonTapped)
                    }
                    .foregroundStyle(DDColor.actionPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())

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
