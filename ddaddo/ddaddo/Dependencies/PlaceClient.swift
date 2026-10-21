//
//  PlaceClient.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture

struct PlaceClient: DependencyKey, Sendable {
    var autocomplete: @Sendable (String) async throws -> [PlaceSearchResult]
    var fetchDetails: @Sendable (PlaceSearchResult) async throws -> PlaceDetails

    static let liveValue: PlaceClient = {
        let service = GooglePlacesService()
        return PlaceClient(
            autocomplete: { query in
                try await service.autocomplete(query: query)
            },
            fetchDetails: { result in
                try await service.fetchDetails(for: result)
            }
        )
    }()

    static let testValue = PlaceClient(
        autocomplete: { _ in [] },
        fetchDetails: { result in
            PlaceDetails(
                id: result.id,
                name: result.name,
                address: result.address,
                category: "장소",
                rating: 0,
                ratingCount: 0,
                latitude: 35.6764,
                longitude: 139.6500,
                photoData: []
            )
        }
    )
}

extension DependencyValues {
    var placeClient: PlaceClient {
        get { self[PlaceClient.self] }
        set { self[PlaceClient.self] = newValue }
    }
}
