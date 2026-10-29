//
//  HomeFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct HomeFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var isMenuPresented = false
    }

    enum Action {
        case exploreTripsButtonTapped
        case menuButtonTapped
        case menuDismissed
        case logoutButtonTapped
        case withdrawButtonTapped
    }

    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .exploreTripsButtonTapped:
                return .none
            case .menuButtonTapped:
                state.isMenuPresented.toggle()
                return .none
            case .menuDismissed:
                state.isMenuPresented = false
                return .none
            case .logoutButtonTapped:
                state.isMenuPresented = false
                return .run { _ in
                    try await authClient.signOut()
                }
            case .withdrawButtonTapped:
                state.isMenuPresented = false
                return .none
            }
        }
    }
}
