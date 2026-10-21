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
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .addTripButtonTapped:
                return .none
            }
        }
    }
}
