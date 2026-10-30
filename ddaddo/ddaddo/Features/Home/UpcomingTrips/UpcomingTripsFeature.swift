//
//  UpcomingTripsFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct UpcomingTripsFeature: Reducer {
    enum Delegate: Equatable {
        case returnHome
    }

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
        var isJoiningTrip = false
        var joinErrorMessage: String?
        var waitingForParticipants: WaitingForParticipantsFeature.State?
        var isWaitingForParticipantsPresented = false

        var isJoinButtonEnabled: Bool {
            inviteCode.count == 6 && !isJoiningTrip
        }
    }

    @CasePathable
    enum Action {
        case backButtonTapped
        case addTripButtonTapped
        case addTripMenuDismissed
        case createTripButtonTapped
        case enterInviteCodeButtonTapped
        case inviteCodeChanged(String)
        case inviteCodeModalDismissed
        case joinTripButtonTapped
        case joinTripResponse(TripInvitationSnapshot)
        case joinTripFailed(String)
        case joinErrorDismissed
        case waitingForParticipantsDismissed
        case waitingForParticipants(WaitingForParticipantsFeature.Action)
        case delegate(Delegate)
        case viewScheduleButtonTapped(Trip.ID)
    }

    @Dependency(\.tripClient) var tripClient

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
                guard !state.isJoiningTrip else { return .none }
                state.isInviteCodeModalPresented = false
                state.inviteCode = ""
                return .none

            case .joinTripButtonTapped:
                guard state.isJoinButtonEnabled else { return .none }
                state.isJoiningTrip = true
                state.joinErrorMessage = nil
                let inviteCode = state.inviteCode
                return .run { send in
                    do {
                        await send(.joinTripResponse(try await tripClient.joinTrip(inviteCode)))
                    } catch {
                        await send(.joinTripFailed(error.localizedDescription))
                    }
                }

            case let .joinTripResponse(snapshot):
                state.isJoiningTrip = false
                state.isInviteCodeModalPresented = false
                state.inviteCode = ""
                state.waitingForParticipants = WaitingForParticipantsFeature.State(snapshot: snapshot)
                state.isWaitingForParticipantsPresented = true
                return .none

            case let .joinTripFailed(message):
                state.isJoiningTrip = false
                state.joinErrorMessage = message
                return .none

            case .joinErrorDismissed:
                state.joinErrorMessage = nil
                return .none

            case .waitingForParticipantsDismissed,
                 .waitingForParticipants(.backButtonTapped):
                state.isWaitingForParticipantsPresented = false
                return .none

            case .waitingForParticipants(.delegate(.returnHome)):
                state.isWaitingForParticipantsPresented = false
                return .send(.delegate(.returnHome))

            case .waitingForParticipants:
                return .none

            case .delegate:
                return .none

            case .viewScheduleButtonTapped:
                return .none
            }
        }
        .ifLet(\.waitingForParticipants, action: \.waitingForParticipants) {
            WaitingForParticipantsFeature()
        }
    }
}
