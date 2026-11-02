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
    var fetchMemberPlaces: @Sendable (String) async throws -> [MemberPlacePins]
    var savePlace: @Sendable (String, PinnedPlace) async throws -> Void
    var deletePlace: @Sendable (String, String) async throws -> Void
    var confirmPlaces: @Sendable (String) async throws -> Void
    var confirmGroups: @Sendable (String, [String]) async throws -> Void
    var fetchGroupConfirmations: @Sendable (String) async throws -> [MemberGroupConfirmation]

    static let liveValue: PlaceClient = {
        let service = GooglePlacesService()
        return PlaceClient(
            autocomplete: { query in
                try await service.autocomplete(query: query)
            },
            fetchDetails: { result in
                try await service.fetchDetails(for: result)
            },
            fetchMemberPlaces: { tripID in
                try await FirebasePlaceSelectionService.fetchMemberPlaces(tripID: tripID)
            },
            savePlace: { tripID, place in
                try await FirebasePlaceSelectionService.savePlace(place, tripID: tripID)
            },
            deletePlace: { tripID, placeID in
                try await FirebasePlaceSelectionService.deletePlace(
                    placeID: placeID,
                    tripID: tripID
                )
            },
            confirmPlaces: { tripID in
                try await FirebasePlaceSelectionService.confirmPlaces(tripID: tripID)
            },
            confirmGroups: { tripID, groupIDs in
                try await FirebasePlaceSelectionService.confirmGroups(
                    tripID: tripID,
                    groupIDs: groupIDs
                )
            },
            fetchGroupConfirmations: { tripID in
                try await FirebasePlaceSelectionService.fetchGroupConfirmations(tripID: tripID)
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
        },
        fetchMemberPlaces: { _ in [] },
        savePlace: { _, _ in },
        deletePlace: { _, _ in },
        confirmPlaces: { _ in },
        confirmGroups: { _, _ in },
        fetchGroupConfirmations: { _ in [] }
    )
}

extension DependencyValues {
    var placeClient: PlaceClient {
        get { self[PlaceClient.self] }
        set { self[PlaceClient.self] = newValue }
    }
}
