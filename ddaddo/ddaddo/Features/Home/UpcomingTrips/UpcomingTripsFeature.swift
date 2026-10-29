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
        var isInviteCodeModalPresented = false
        var inviteCode = ""

        var isJoinButtonEnabled: Bool {
            inviteCode.count == 6
        }
    }

    enum Action {
        case backButtonTapped
        case addTripButtonTapped
        case addTripMenuDismissed
        case createTripButtonTapped
        case enterInviteCodeButtonTapped
        case inviteCodeChanged(String)
        case inviteCodeModalDismissed
        case joinTripButtonTapped
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

            case .createTripButtonTapped:
                state.isAddTripMenuPresented = false
                return .none

            case .enterInviteCodeButtonTapped:
                state.isAddTripMenuPresented = false
                state.inviteCode = ""
                state.isInviteCodeModalPresented = true
                return .none

            case let .inviteCodeChanged(code):
                state.inviteCode = String(code.filter(\.isNumber).prefix(6))
                return .none

            case .inviteCodeModalDismissed:
                state.isInviteCodeModalPresented = false
                state.inviteCode = ""
                return .none

            case .joinTripButtonTapped:
                guard state.isJoinButtonEnabled else { return .none }
                state.isInviteCodeModalPresented = false
                return .none

            case .viewScheduleButtonTapped:
                return .none
            }
        }
    }
}
