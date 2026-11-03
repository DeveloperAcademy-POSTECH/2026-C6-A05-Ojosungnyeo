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
        var isLoadingTrips = false
        var isAddTripMenuPresented = false
        var isInviteCodeModalPresented = false
        var inviteCode = ""
        var isJoiningTrip = false
        var joinErrorMessage: String?
        var pendingDeletionTripID: Trip.ID?
        var isDeletingTrip = false
        var deletionErrorMessage: String?
        var waitingForParticipants: WaitingForParticipantsFeature.State?
        var isWaitingForParticipantsPresented = false

        var isJoinButtonEnabled: Bool {
            inviteCode.count == 6 && !isJoiningTrip
        }
    }

    @CasePathable
    enum Action {
        case onAppear
        case upcomingTripsResponse(Result<[UpcomingTripSnapshot], Error>)
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
        case deleteButtonTapped(Trip.ID)
        case deleteCancelButtonTapped
        case deleteConfirmButtonTapped
        case deleteTripResponse(Trip.ID, Result<Void, Error>)
        case deletionErrorDismissed
        case waitingForParticipantsDismissed
        case waitingForParticipants(WaitingForParticipantsFeature.Action)
        case delegate(Delegate)
        case viewScheduleButtonTapped(Trip.ID)
    }

    @Dependency(\.tripClient) var tripClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoadingTrips else { return .none }
                state.isLoadingTrips = true
                return fetchUpcomingTripsEffect()

            case let .upcomingTripsResponse(.success(snapshots)):
                state.isLoadingTrips = false
                var trips: [Trip] = []
                for snapshot in snapshots {
                    trips.append(Self.makeTrip(from: snapshot))
                }
                state.trips = trips
                return .none

            case .upcomingTripsResponse(.failure):
                state.isLoadingTrips = false
                return .none

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
                return fetchUpcomingTripsEffect()

            case let .joinTripFailed(message):
                state.isJoiningTrip = false
                state.joinErrorMessage = message
                return .none

            case .joinErrorDismissed:
                state.joinErrorMessage = nil
                return .none

            case let .deleteButtonTapped(tripID):
                guard state.pendingDeletionTripID == nil,
                      state.trips.contains(where: { $0.id == tripID }) else { return .none }
                state.pendingDeletionTripID = tripID
                return .none

            case .deleteCancelButtonTapped:
                state.pendingDeletionTripID = nil
                return .none

            case .deleteConfirmButtonTapped:
                guard let tripID = state.pendingDeletionTripID,
                      !state.isDeletingTrip else { return .none }
                state.isDeletingTrip = true
                state.pendingDeletionTripID = nil
                return .run { send in
                    await send(
                        .deleteTripResponse(
                            tripID,
                            Result { try await tripClient.deleteUpcomingTrip(tripID) }
                        )
                    )
                }

            case let .deleteTripResponse(tripID, .success):
                state.isDeletingTrip = false
                state.trips.removeAll { $0.id == tripID }
                return .none

            case let .deleteTripResponse(_, .failure(error)):
                state.isDeletingTrip = false
                state.deletionErrorMessage = error.localizedDescription
                return .none

            case .deletionErrorDismissed:
                state.deletionErrorMessage = nil
                return .none

            case .waitingForParticipantsDismissed,
                 .waitingForParticipants(.backButtonTapped):
                state.isWaitingForParticipantsPresented = false
                return .none

            case .waitingForParticipants(.delegate(.returnHome)):
                state.isWaitingForParticipantsPresented = false
                return .merge(
                    fetchUpcomingTripsEffect(),
                    .send(.delegate(.returnHome))
                )

            case .waitingForParticipants(.delegate(.returnToUpcomingTrips)):
                state.isWaitingForParticipantsPresented = false
                return fetchUpcomingTripsEffect()

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

    private func fetchUpcomingTripsEffect() -> Effect<Action> {
        .run { send in
            await send(
                .upcomingTripsResponse(
                    Result { try await tripClient.fetchUpcomingTrips() }
                )
            )
        }
    }

    private static func makeTrip(from snapshot: UpcomingTripSnapshot) -> Trip {
        let destination = switch snapshot.destinationName {
        case "도쿄": "TOKYO"
        case "상하이": "SHANGHAI"
        case "시드니": "SYDNEY"
        default: snapshot.destinationName.uppercased()
        }
        let country = switch snapshot.countryName {
        case "일본": "Japan"
        case "중국": "China"
        case "호주": "Australia"
        default: snapshot.countryName
        }

        return Trip(
            id: snapshot.tripID,
            destination: destination,
            country: country,
            dateText: dateText(from: snapshot.startDate, to: snapshot.endDate)
        )
    }

    private static func dateText(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startMonth = calendar.component(.month, from: startDate)
        let startDay = calendar.component(.day, from: startDate)
        let startYear = calendar.component(.year, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)
        let endDay = calendar.component(.day, from: endDate)
        let yearPrefix = startYear > calendar.component(.year, from: Date())
            ? "\(startYear % 100)년 "
            : ""

        if startMonth == endMonth {
            return "\(yearPrefix)\(startMonth)월 \(startDay)일~\(endDay)일"
        }
        return "\(yearPrefix)\(startMonth)월 \(startDay)일~\(endMonth)월 \(endDay)일"
    }
}
