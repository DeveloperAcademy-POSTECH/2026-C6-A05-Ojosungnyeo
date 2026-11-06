//
//  PlaceDetails.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import Foundation

struct PlaceDetails: Equatable, Sendable {
    let id: String
    let name: String
    let address: String
    let category: String
    let rating: Double
    let ratingCount: Int
    let latitude: Double
    let longitude: Double
    let photoData: [Data]
}
