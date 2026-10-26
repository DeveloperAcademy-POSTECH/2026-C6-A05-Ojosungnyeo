//
//  TripSetUpFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct TripSetUpFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        static let maximumTravelerCount = 4

        var destinationName = "도쿄"
        var countryName = "일본"
        var cityCount = 1
        var travelerCount = 1

        var tripTitle: String { "\(destinationName) 여행" }
        var destinationSummary: String { "\(countryName) · \(cityCount)개 도시" }
    }

    enum Action: Equatable {
        case backButtonTapped
        case destinationChangeButtonTapped
        case travelScheduleButtonTapped
        case travelerDecreaseButtonTapped
        case travelerIncreaseButtonTapped
        case flightInfoButtonTapped
        case accommodationInfoButtonTapped
        case inviteFriendButtonTapped
        case saveButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .travelerDecreaseButtonTapped:
                guard state.travelerCount > 1 else { return .none }
                state.travelerCount -= 1
                return .none

            case .travelerIncreaseButtonTapped:
                guard state.travelerCount < State.maximumTravelerCount else { return .none }
                state.travelerCount += 1
                return .none

            case .backButtonTapped,
                 .destinationChangeButtonTapped,
                 .travelScheduleButtonTapped,
                 .flightInfoButtonTapped,
                 .accommodationInfoButtonTapped,
                 .inviteFriendButtonTapped,
                 .saveButtonTapped:
                return .none
            }
        }
    }
}
