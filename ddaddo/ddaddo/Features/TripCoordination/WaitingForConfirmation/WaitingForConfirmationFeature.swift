//
//  WaitingForConfirmationFeature.swift
//  ddaddo
//
//  Created by sun on 11/1/26.
//

import ComposableArchitecture

struct WaitingForConfirmationFeature: Reducer {
    enum Delegate: Equatable {
        case proceedToItinerary
    }

    struct Member: Equatable, Identifiable {
        let id: String
        let name: String
        let avatar: ParticipantAvatar
        let isConfirmed: Bool
    }

    @ObservableState
    struct State: Equatable {
        var tripID = "preview-trip"
        var tripTitle = WaitingForConfirmationPreviewData.tripTitle
        var tripDates = WaitingForConfirmationPreviewData.tripDates
        var members = WaitingForConfirmationPreviewData.members

        var confirmedCount: Int {
            members.filter(\.isConfirmed).count
        }

        var haveAllMembersConfirmed: Bool {
            !members.isEmpty && confirmedCount == members.count
        }

        init() {}

        init(
            tripID: String,
            tripTitle: String,
            tripDates: String,
            members: [PlaceGroupingFeature.Member],
            currentMemberID: String
        ) {
            self.tripID = tripID
            self.tripTitle = tripTitle
            self.tripDates = tripDates
            self.members = members.map {
                Member(
                    id: $0.id,
                    name: $0.name,
                    avatar: $0.avatar,
                    isConfirmed: $0.id == currentMemberID
                )
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case onDisappear
        case refresh
        case confirmationsResponse([MemberGroupConfirmation])
        case confirmationsFailed
        case backButtonTapped
        case completionButtonTapped
        case nudgeButtonTapped(String)
        case completionButtonTapped
        case groupingCompleted
        case delegate(Delegate)
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    fetchConfirmations(tripID: state.tripID),
                    .run { send in
                        while !Task.isCancelled {
                            try await clock.sleep(for: .seconds(3))
                            await send(.refresh)
                        }
                    }
                    .cancellable(id: "group-confirmation-poll", cancelInFlight: true)
                )
            case .refresh:
                return fetchConfirmations(tripID: state.tripID)
            case let .confirmationsResponse(confirmations):
                let values = Dictionary(uniqueKeysWithValues: confirmations.map { ($0.member.rawValue, $0) })
                state.members = state.members.map { member in
                    guard let confirmation = values[member.id] else { return member }
                    return Member(
                        id: member.id,
                        name: displayName(confirmation.name),
                        avatar: member.avatar,
                        isConfirmed: confirmation.isConfirmed
                    )
                }
                return .none
            case .confirmationsFailed, .nudgeButtonTapped, .completionButtonTapped:
                return .none
            case .completionButtonTapped:
                guard state.haveAllMembersConfirmed else { return .none }
                let tripID = state.tripID
                return .run { send in
                    try await placeClient.completeGrouping(tripID)
                    await send(.groupingCompleted)
                }
            case .groupingCompleted:
                return .merge(
                    .cancel(id: "group-confirmation-poll"),
                    .send(.delegate(.proceedToItinerary))
                )
            case .delegate:
                return .none
            case .onDisappear, .backButtonTapped:
                return .cancel(id: "group-confirmation-poll")
            }
        }
    }

    private func fetchConfirmations(tripID: String) -> Effect<Action> {
        .run { send in
            do {
                await send(.confirmationsResponse(
                    try await placeClient.fetchGroupConfirmations(tripID)
                ))
            } catch {
                await send(.confirmationsFailed)
            }
        }
    }

    private func displayName(_ name: String) -> String {
        name.count > 3 ? "\(name.prefix(3))···" : name
    }
}
