//
//  TripSetUpTransportationFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct TripSetUpTransportationFeature: Reducer {
    struct Selection: Equatable {
        let transportation: Transportation
        let duration: TravelDuration
    }

    @ObservableState
    struct State: Equatable {
        var selectedTransportation: Transportation = .publicTransit
        var selectedDuration: TravelDuration = .thirtyMinutes

        init(selection: Selection? = nil) {
            if let selection {
                selectedTransportation = selection.transportation
                selectedDuration = selection.duration
            }
        }

        var selection: Selection {
            Selection(
                transportation: selectedTransportation,
                duration: selectedDuration
            )
        }
    }

    @CasePathable
    enum Action: Equatable {
        case closeButtonTapped
        case confirmButtonTapped
        case transportationSelected(Transportation)
        case durationSelected(TravelDuration)
        case delegate(DelegateAction)
    }

    enum DelegateAction: Equatable {
        case dismiss
        case completed(Selection)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeButtonTapped:
                return .send(.delegate(.dismiss))

            case .confirmButtonTapped:
                return .send(.delegate(.completed(state.selection)))

            case let .transportationSelected(transportation):
                state.selectedTransportation = transportation
                return .none

            case let .durationSelected(duration):
                state.selectedDuration = duration
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
