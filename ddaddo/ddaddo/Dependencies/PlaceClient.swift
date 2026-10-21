//
//  PlaceClient.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture

struct PlaceClient: DependencyKey, Sendable {
    var autocomplete: @Sendable (String) async throws -> [PlaceSearchResult]

    static let liveValue: PlaceClient = {
        let service = GooglePlacesService()
        return PlaceClient(
            autocomplete: { query in
                try await service.autocomplete(query: query)
            }
        )
    }()

    static let testValue = PlaceClient(
        autocomplete: { _ in [] }
    )
}

extension DependencyValues {
    var placeClient: PlaceClient {
        get { self[PlaceClient.self] }
        set { self[PlaceClient.self] = newValue }
    }
}
