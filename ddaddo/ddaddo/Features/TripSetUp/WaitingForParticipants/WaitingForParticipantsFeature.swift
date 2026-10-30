//
//  WaitingForParticipantsFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct WaitingForParticipantsFeature: Reducer {
    struct Participant: Equatable, Identifiable {
        let id: Int
        let name: String
        let avatarName: String?
        let hasJoined: Bool
    }

    struct Invitation: Equatable {
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
    }

    @Dependency(\.continuousClock) var clock

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
                guard !state.isRefreshing else { return .none }
                state.isRefreshing = true
                let invitation = Invitation.mock(expiresAt: state.invitation.expiresAt)
                return .run { send in
                    try await clock.sleep(for: .milliseconds(350))
                    await send(.refreshCompleted(invitation, Date()))
                }
                .cancellable(id: "waiting-participants-refresh")

            case let .refreshCompleted(invitation, now):
                state.invitation = invitation
                state.currentDate = now
                state.isRefreshing = false
                return .none

            case .mapButtonTapped:
                guard state.joinedCount < state.invitation.participants.count else {
                    state.isPlaceSelectionPresented = true
                    return .none
                }
                state.isMapConfirmationPresented = true
                return .none

            case .mapConfirmationCancelButtonTapped:
                state.isMapConfirmationPresented = false
                return .none

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
    static func mock(expiresAt: Date) -> Self {
        Self(
            code: "000000",
            url: nil,
            expiresAt: expiresAt,
            participants: [
                .init(id: 1, name: "테이", avatarName: "DDMiniHeadTae", hasJoined: true),
                .init(id: 2, name: "한아름…", avatarName: "DDMiniHeadHeader", hasJoined: true),
                .init(id: 3, name: "친구 3", avatarName: nil, hasJoined: false),
                .init(id: 4, name: "친구 4", avatarName: nil, hasJoined: false)
            ]
        )
    }
}
