//
//  DestinationClient.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import ComposableArchitecture

struct DestinationClient: DependencyKey, Sendable {
    var fetchDestinations: @MainActor @Sendable () async throws -> [TripDestination]

    static let liveValue = Self(
        fetchDestinations: {
            try await FirebaseDestinationService.fetchDestinations()
        }
    )

    static let testValue = Self(fetchDestinations: { [] })
}

extension DependencyValues {
    var destinationClient: DestinationClient {
        get { self[DestinationClient.self] }
        set { self[DestinationClient.self] = newValue }
    }
}
