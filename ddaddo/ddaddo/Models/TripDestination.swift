//
//  TripDestination.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import Foundation

struct TripDestination: Equatable, Identifiable, Sendable {
    enum Region: String, CaseIterable, Equatable, Sendable {
        case asia = "아시아"
        case southeastAsia = "동남아"
        case europe = "유럽"
        case americasAndOceania = "미주/오세아니아"

        var serverValue: String {
            switch self {
            case .asia: "asia"
            case .southeastAsia: "southeastAsia"
            case .europe: "europe"
            case .americasAndOceania: "americasAndOceania"
            }
        }

        init?(serverValue: String) {
            switch serverValue {
            case "asia", Self.asia.rawValue: self = .asia
            case "southeastAsia", Self.southeastAsia.rawValue: self = .southeastAsia
            case "europe", Self.europe.rawValue: self = .europe
            case "americasAndOceania", Self.americasAndOceania.rawValue: self = .americasAndOceania
            default: return nil
            }
        }
    }

    let id: String
    let country: String
    let name: String
    let region: Region
    let thumbnailName: String
    let sortOrder: Int
}
