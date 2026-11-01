//
//  WaitingForConfirmationFeature.swift
//  ddaddo
//
//  Created by sun on 11/1/26.
//

import ComposableArchitecture

struct WaitingForConfirmationFeature: Reducer {
    struct Member: Equatable, Identifiable {
        let id: String
        let name: String
        let avatar: ParticipantAvatar
        let isConfirmed: Bool
    }

    @ObservableState
    struct State: Equatable {
        var tripTitle = WaitingForConfirmationPreviewData.tripTitle
        var tripDates = WaitingForConfirmationPreviewData.tripDates
        var members = WaitingForConfirmationPreviewData.members

        var confirmedCount: Int {
            members.filter(\.isConfirmed).count
        }
    }

    enum Action: Equatable {
        case backButtonTapped
        case nudgeButtonTapped(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { _, _ in
            .none
        }
    }
}
