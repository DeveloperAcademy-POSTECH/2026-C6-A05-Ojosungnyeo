//
//  MapPlaceGroup.swift
//  ddaddo
//
//  Created by sun on 11/1/26.
//

struct MapPlaceGroup: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let places: [PinnedPlace]
    let radius: Double

    var centerLatitude: Double {
        guard !places.isEmpty else { return 0 }
        return places.map(\.latitude).reduce(0, +) / Double(places.count)
    }

    var centerLongitude: Double {
        guard !places.isEmpty else { return 0 }
        return places.map(\.longitude).reduce(0, +) / Double(places.count)
    }
}
