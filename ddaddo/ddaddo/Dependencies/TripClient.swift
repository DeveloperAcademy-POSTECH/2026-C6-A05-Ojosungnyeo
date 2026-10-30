//
//  TripClient.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import ComposableArchitecture

struct TripClient: DependencyKey, Sendable {
    var createTrip: @MainActor @Sendable (TripCreationRequest) async throws -> TripInvitationSnapshot
    var fetchInvitation: @MainActor @Sendable (String) async throws -> TripInvitationSnapshot

    static let liveValue = Self(
        createTrip: { request in
            try await FirebaseTripService.createTrip(request)
        },
        fetchInvitation: { tripID in
            try await FirebaseTripService.fetchInvitation(tripID: tripID)
        }
    )

    static let testValue = Self(
        createTrip: { _ in throw CancellationError() },
        fetchInvitation: { _ in throw CancellationError() }
    )
}

extension DependencyValues {
    var tripClient: TripClient {
        get { self[TripClient.self] }
        set { self[TripClient.self] = newValue }
    }
}
