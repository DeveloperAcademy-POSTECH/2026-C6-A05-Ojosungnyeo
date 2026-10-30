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
        let url: URL
        let expiresAt: Date
        let participants: [Participant]
    }

    @ObservableState
    struct State: Equatable {
        static let mockDuration: TimeInterval = 65 * 60 + 14

        var invitation: Invitation
        var countdownDuration: TimeInterval
        var currentDate: Date
        var isRefreshing = false

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
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            return String(format: "%02d:%02d", minutes, seconds)
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

            case .backButtonTapped, .mapButtonTapped:
                return .none
            }
        }
    }
}

private extension WaitingForParticipantsFeature.Invitation {
    static func mock(expiresAt: Date) -> Self {
        Self(
            code: "999994",
            // Replace with the server-provided web invitation URL when available.
            url: URL(string: "https://ddaddo-web.vercel.app/invite")!,
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
