//
//  UpcomingTripsFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct UpcomingTripsFeature: Reducer {
    struct Trip: Equatable, Identifiable {
        let id: String
        let destination: String
        let dateText: String
        let participantCount: Int
        let imageName: String
    }

    @ObservableState
    struct State: Equatable {
        var trips: [Trip] = []
    }

    enum Action {
        case backButtonTapped
        case addTripButtonTapped
        case notificationButtonTapped
        case viewScheduleButtonTapped(Trip.ID)
        case inviteButtonTapped(Trip.ID)
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .backButtonTapped,
                 .addTripButtonTapped,
                 .notificationButtonTapped,
                 .viewScheduleButtonTapped,
                 .inviteButtonTapped:
                return .none
            }
        }
    }
}
