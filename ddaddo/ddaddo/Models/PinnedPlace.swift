//
//  PinnedPlace.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

struct PinnedPlace: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let thumbnailName: String
    let latitude: Double
    let longitude: Double
}
