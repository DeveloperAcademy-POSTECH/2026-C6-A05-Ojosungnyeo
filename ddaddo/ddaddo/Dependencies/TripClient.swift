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
    var joinTrip: @MainActor @Sendable (String) async throws -> TripInvitationSnapshot
    var fetchUpcomingTrips: @MainActor @Sendable () async throws -> [UpcomingTripSnapshot]
    var deleteUpcomingTrip: @MainActor @Sendable (String) async throws -> Void
    var saveItinerary: @MainActor @Sendable (TripItinerarySaveRequest) async throws -> Void
    var fetchItinerary: @MainActor @Sendable (String) async throws -> TripItinerarySnapshot?

    static let liveValue = Self(
        createTrip: { request in
            try await FirebaseTripService.createTrip(request)
        },
        fetchInvitation: { tripID in
            try await FirebaseTripService.fetchInvitation(tripID: tripID)
        },
        joinTrip: { inviteCode in
            try await FirebaseTripService.joinTrip(inviteCode: inviteCode)
        },
        fetchUpcomingTrips: {
            try await FirebaseTripService.fetchUpcomingTrips()
        },
        deleteUpcomingTrip: { tripID in
            try await FirebaseTripService.deleteUpcomingTrip(tripID: tripID)
        },
        saveItinerary: { request in
            try await FirebaseTripService.saveItinerary(request)
        },
        fetchItinerary: { tripID in
            try await FirebaseTripService.fetchItinerary(tripID: tripID)
        }
    )

    static let testValue = Self(
        createTrip: { _ in throw CancellationError() },
        fetchInvitation: { _ in throw CancellationError() },
        joinTrip: { _ in throw CancellationError() },
        fetchUpcomingTrips: { [] },
        deleteUpcomingTrip: { _ in },
        saveItinerary: { _ in },
        fetchItinerary: { _ in nil }
    )
}

extension DependencyValues {
    var tripClient: TripClient {
        get { self[TripClient.self] }
        set { self[TripClient.self] = newValue }
    }
}
