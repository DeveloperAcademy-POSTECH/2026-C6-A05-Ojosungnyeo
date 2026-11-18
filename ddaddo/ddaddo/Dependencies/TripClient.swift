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
    var resetDevelopmentMockTrips: @MainActor @Sendable () async throws -> Void
    var saveRecommendations: @MainActor @Sendable (String, [TripRecommendationSnapshot]) async throws -> Void
    var saveItinerary: @MainActor @Sendable (TripItinerarySaveRequest) async throws -> Void
    var fetchItinerary: @MainActor @Sendable (String) async throws -> TripItinerarySnapshot?
    var observeItinerary: @MainActor @Sendable (String) -> AsyncThrowingStream<TripItinerarySnapshot?, Error>

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
        resetDevelopmentMockTrips: {
            #if DEBUG
            try await DevelopmentMockTripService.reset()
            #endif
        },
        saveRecommendations: { tripID, recommendations in
            try await FirebaseTripService.saveRecommendations(
                tripID: tripID,
                recommendations: recommendations
            )
        },
        saveItinerary: { request in
            try await FirebaseTripService.saveItinerary(request)
        },
        fetchItinerary: { tripID in
            try await FirebaseTripService.fetchItinerary(tripID: tripID)
        },
        observeItinerary: { tripID in
            FirebaseTripService.observeItinerary(tripID: tripID)
        }
    )

    static let testValue = Self(
        createTrip: { _ in throw CancellationError() },
        fetchInvitation: { _ in throw CancellationError() },
        joinTrip: { _ in throw CancellationError() },
        fetchUpcomingTrips: { [] },
        deleteUpcomingTrip: { _ in },
        resetDevelopmentMockTrips: {},
        saveRecommendations: { _, _ in },
        saveItinerary: { _ in },
        fetchItinerary: { _ in nil },
        observeItinerary: { _ in
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var tripClient: TripClient {
        get { self[TripClient.self] }
        set { self[TripClient.self] = newValue }
    }
}
