//
//  WaitingForParticipantsFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct WaitingForParticipantsFeature: Reducer {
    enum Delegate: Equatable {
        case returnHome
    }

    struct Participant: Equatable, Identifiable {
        let id: Int
        let name: String
        let avatarName: String?
        let hasJoined: Bool

        var displayName: String {
            if name.hasPrefix("친구 "),
               name.dropFirst(3).allSatisfy(\.isNumber) {
                return name
            }
            guard name.count > 3 else { return name }
            return "\(name.prefix(3))···"
        }
    }

    struct Invitation: Equatable {
        let tripID: String
        let code: String
        let url: URL?
        let expiresAt: Date
        let participants: [Participant]

        var shareURL: URL {
            url ?? URL(string: "https://ddaddo-web.vercel.app/invite?code=\(code)")!
        }

        var shareText: String {
            "따또에서 친구의 여행 초대가 도착했어요! 💌\n초대에 응하고 72시간 안에 가고 싶은 장소를 입력하세요.\n\(shareURL.absoluteString)"
        }
    }

    @ObservableState
    struct State: Equatable {
        static let mockDuration: TimeInterval = 72 * 60 * 60

        var invitation: Invitation
        var countdownDuration: TimeInterval
        var currentDate: Date
        var isRefreshing = false
        var isMapConfirmationPresented = false
        var placeSelection = PlaceSelectionFeature.State()
        var isPlaceSelectionPresented = false

        init(invitation: Invitation, countdownDuration: TimeInterval, currentDate: Date = Date()) {
            self.invitation = invitation
            self.countdownDuration = countdownDuration
            self.currentDate = currentDate
        }

        init(snapshot: TripInvitationSnapshot, currentDate: Date = Date()) {
            invitation = Invitation(snapshot: snapshot)
            countdownDuration = Self.mockDuration
            self.currentDate = currentDate
        }

        static func mock(now: Date = Date()) -> Self {
            let expiresAt = now.addingTimeInterval(mockDuration)
            return Self(
                invitation: .mock(expiresAt: expiresAt),
                countdownDuration: mockDuration,
                currentDate: now
            )
        }

        var remainingTime: TimeInterval {
            max(0, invitation.expiresAt.timeIntervalSince(currentDate))
        }

        var remainingSeconds: Int {
            Int(ceil(remainingTime))
        }

        var timerText: String {
            let hours = remainingSeconds / 3_600
            let minutes = remainingSeconds % 3_600 / 60
            return String(format: "%02d:%02d", hours, minutes)
        }

        var timerProgress: Double {
            guard countdownDuration > 0 else { return 0 }
            return min(1, max(0, remainingTime / countdownDuration))
        }

        var joinedCount: Int {
            invitation.participants.filter(\.hasJoined).count
        }

        var haveAllParticipantsJoined: Bool {
            !invitation.participants.isEmpty
                && joinedCount == invitation.participants.count
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case onDisappear
        case timerTicked(Date)
        case backButtonTapped
        case refreshTapped
        case refreshCompleted(Invitation, Date)
        case mapButtonTapped
        case mapConfirmationCancelButtonTapped
        case mapConfirmationConfirmButtonTapped
        case placeSelectionDismissed
        case placeSelection(PlaceSelectionFeature.Action)
        case delegate(Delegate)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.tripClient) var tripClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.currentDate = Date()
                return .run { send in
                    while true {
                        try await clock.sleep(for: .seconds(1))
                        await send(.timerTicked(Date()))
                    }
                }
                .cancellable(id: "waiting-participants-timer", cancelInFlight: true)

            case .onDisappear:
                state.isRefreshing = false
                return .merge(
                    .cancel(id: "waiting-participants-timer"),
                    .cancel(id: "waiting-participants-refresh")
                )

            case let .timerTicked(now):
                state.currentDate = now
                return .none

            case .refreshTapped:
                guard !state.isRefreshing, !state.haveAllParticipantsJoined else { return .none }
                state.isRefreshing = true
                let tripID = state.invitation.tripID
                let fallbackInvitation = state.invitation
                return .run { send in
                    do {
                        let snapshot = try await tripClient.fetchInvitation(tripID)
                        await send(.refreshCompleted(Invitation(snapshot: snapshot), Date()))
                    } catch {
                        await send(.refreshCompleted(fallbackInvitation, Date()))
                    }
                }
                .cancellable(id: "waiting-participants-refresh")

            case let .refreshCompleted(invitation, now):
                state.invitation = invitation
                state.currentDate = now
                state.isRefreshing = false
                return .none

            case .mapButtonTapped:
                if state.haveAllParticipantsJoined {
                    state.isMapConfirmationPresented = false
                    state.isPlaceSelectionPresented = true
                    return .none
                }

                state.isPlaceSelectionPresented = false
                state.isMapConfirmationPresented = true
                return .none

            case .mapConfirmationCancelButtonTapped:
                state.isMapConfirmationPresented = false
                return .send(.delegate(.returnHome))

            case .mapConfirmationConfirmButtonTapped:
                guard state.isMapConfirmationPresented else { return .none }
                state.isMapConfirmationPresented = false
                state.isPlaceSelectionPresented = true
                return .none

            case .placeSelectionDismissed, .placeSelection(.backButtonTapped):
                state.isPlaceSelectionPresented = false
                return .none

            case .placeSelection:
                return .none

            case .delegate:
                return .none

            case .backButtonTapped:
                return .none
            }
        }

        Scope(state: \.placeSelection, action: \.placeSelection) {
            PlaceSelectionFeature()
        }
    }
}

private extension WaitingForParticipantsFeature.Invitation {
    init(snapshot: TripInvitationSnapshot) {
        self.init(
            tripID: snapshot.tripID,
            code: snapshot.code,
            url: snapshot.url,
            expiresAt: snapshot.expiresAt,
            participants: snapshot.participants.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    avatarName: $0.avatarName,
                    hasJoined: $0.hasJoined
                )
            }
        )
    }

    static func mock(expiresAt: Date) -> Self {
        Self(
            tripID: "preview-trip",
            code: "999994",
            // Replace with the server-provided web invitation URL when available.
            url: URL(string: "https://ddaddo-web.vercel.app/invite")!,
            expiresAt: expiresAt,
            participants: [
                .init(id: 1, name: "테이", avatarName: "DDMiniHeadTae", hasJoined: true),
                .init(id: 2, name: "헤더", avatarName: "DDMiniHeadHeader", hasJoined: true),
                .init(id: 3, name: "그레", avatarName: "DDMiniHeadGrae", hasJoined: false),
                .init(id: 4, name: "주니", avatarName: "DDMiniHeadJuni", hasJoined: false)
            ]
        )
    }
}
