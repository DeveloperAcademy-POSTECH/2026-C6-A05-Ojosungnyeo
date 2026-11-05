//
//  PinnedPlace.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import Foundation

struct PinnedPlace: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let thumbnailName: String
    let category: String
    let photoData: [Data]
    let latitude: Double
    let longitude: Double

    nonisolated init(
        id: String,
        name: String,
        description: String,
        thumbnailName: String,
        category: String = "장소",
        photoData: [Data] = [],
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.thumbnailName = thumbnailName
        self.category = category
        self.photoData = photoData
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct MemberPlacePins: Equatable, Sendable {
    let member: TripMember
    let places: [PinnedPlace]
    let isConfirmed: Bool
}

struct MemberGroupConfirmation: Equatable, Sendable {
    let member: TripMember
    let name: String
    let isConfirmed: Bool
}

struct MemberGroupMembership: Equatable, Sendable {
    let member: TripMember
    let groupIDs: [String]
    let confirmedGroupIDs: [String]
    let deletedPlaceIDsByGroupID: [String: [String]]
    let orderedPlaceIDsByGroupID: [String: [String]]
    let latestGroupEdit: GroupEditEvent?
}

struct GroupEditEvent: Equatable, Sendable {
    let id: String
    let groupID: String
    let editor: TripMember
    let editorName: String
}
