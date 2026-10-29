//
//  UpcomingTripsFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct UpcomingTripsFeature: Reducer {
    struct Trip: Equatable, Identifiable {
        let id: String
        let destination: String
        let country: String
        let dateText: String
    }

    @ObservableState
    struct State: Equatable {
        var trips: [Trip] = []
        var isAddTripMenuPresented = false
    }

    enum Action {
        case backButtonTapped
        case addTripButtonTapped
        case addTripMenuDismissed
        case createTripButtonTapped
        case enterInviteCodeButtonTapped
        case viewScheduleButtonTapped(Trip.ID)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                state.isAddTripMenuPresented = false
                return .none

            case .addTripButtonTapped:
                state.isAddTripMenuPresented.toggle()
                return .none

            case .addTripMenuDismissed:
                state.isAddTripMenuPresented = false
                return .none

            case .createTripButtonTapped,
                 .enterInviteCodeButtonTapped:
                state.isAddTripMenuPresented = false
                return .none

            case .viewScheduleButtonTapped:
                return .none
            }
        }
    }
}
