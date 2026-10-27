//
//  TransportationSelectFeature.swift
//  ddaddo
//
//  Created by sun on 10/23/26.
//

import ComposableArchitecture

struct TransportationSelectFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var selectedTransportation: Transportation?
        var selectedDuration: TravelDuration?

        var isSelectionComplete: Bool {
            selectedTransportation != nil && selectedDuration != nil
        }
    }

    enum Action: Equatable {
        case backButtonTapped
        case transportationSelected(Transportation)
        case durationSelected(TravelDuration)
        case recommendationButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                return .none

            case .recommendationButtonTapped:
                guard state.isSelectionComplete else { return .none }
                return .none

            case let .transportationSelected(transportation):
                state.selectedTransportation = transportation
                return .none

            case let .durationSelected(duration):
                state.selectedDuration = duration
                return .none
            }
        }
    }
}

enum Transportation: String, CaseIterable, Equatable, Identifiable {
    case car
    case publicTransit

    var id: Self { self }

    var title: String {
        switch self {
        case .car: "자동차"
        case .publicTransit: "대중교통"
        }
    }

    var imageName: String {
        switch self {
        case .car: "DDTransportationCar"
        case .publicTransit: "DDTransportationTransit"
        }
    }
}

enum TravelDuration: Int, CaseIterable, Equatable, Identifiable {
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case sixtyMinutes = 60

    var id: Self { self }
    var title: String { "\(rawValue)분" }
}
