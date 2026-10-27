//
//  HomeFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct HomeFeature: Reducer {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case addTripButtonTapped
        case menuButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .addTripButtonTapped:
                return .none
            case .menuButtonTapped:
                return .none
            }
        }
    }
}
