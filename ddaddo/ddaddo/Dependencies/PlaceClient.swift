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
    var observeMemberPlaces: @Sendable (String) -> AsyncThrowingStream<[MemberPlacePins], Error>
    var savePlace: @Sendable (String, PinnedPlace) async throws -> Void
    var deletePlace: @Sendable (String, String) async throws -> Void
    var replacePlaces: @Sendable (String, [PinnedPlace]) async throws -> Void
    var confirmPlaces: @Sendable (String) async throws -> Void
    var joinGroup: @Sendable (String, String) async throws -> Void
    var observeGroupMemberships: @Sendable (String) -> AsyncThrowingStream<[MemberGroupMembership], Error>
    var confirmGroups: @Sendable (String, [String]) async throws -> Void
    var fetchGroupConfirmations: @Sendable (String) async throws -> [MemberGroupConfirmation]
    var completeGrouping: @Sendable (String) async throws -> Void

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
            observeMemberPlaces: { tripID in
                FirebasePlaceSelectionService.observeMemberPlaces(tripID: tripID)
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
            replacePlaces: { tripID, places in
                try await FirebasePlaceSelectionService.replacePlaces(
                    places,
                    tripID: tripID
                )
            },
            confirmPlaces: { tripID in
                try await FirebasePlaceSelectionService.confirmPlaces(tripID: tripID)
            },
            joinGroup: { tripID, groupID in
                try await FirebasePlaceSelectionService.joinGroup(
                    tripID: tripID,
                    groupID: groupID
                )
            },
            observeGroupMemberships: { tripID in
                FirebasePlaceSelectionService.observeGroupMemberships(tripID: tripID)
            },
            confirmGroups: { tripID, groupIDs in
                try await FirebasePlaceSelectionService.confirmGroups(
                    tripID: tripID,
                    groupIDs: groupIDs
                )
            },
            fetchGroupConfirmations: { tripID in
                try await FirebasePlaceSelectionService.fetchGroupConfirmations(tripID: tripID)
            },
            completeGrouping: { tripID in
                try await FirebasePlaceSelectionService.completeGrouping(tripID: tripID)
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
        observeMemberPlaces: { _ in AsyncThrowingStream { $0.finish() } },
        savePlace: { _, _ in },
        deletePlace: { _, _ in },
        replacePlaces: { _, _ in },
        confirmPlaces: { _ in },
        joinGroup: { _, _ in },
        observeGroupMemberships: { _ in AsyncThrowingStream { $0.finish() } },
        confirmGroups: { _, _ in },
        fetchGroupConfirmations: { _ in [] },
        completeGrouping: { _ in }
    )
}

extension DependencyValues {
    var placeClient: PlaceClient {
        get { self[PlaceClient.self] }
        set { self[PlaceClient.self] = newValue }
    }
}
