//
//  GoogleMapsService.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import Foundation
import GoogleMaps
import GooglePlaces

enum GoogleMapsService {
    private(set) static var isConfigured = false

    @discardableResult
    static func configure() -> Bool {
        if isConfigured {
            return true
        }

        guard
            let apiKey = Bundle.main.object(
                forInfoDictionaryKey: "GoogleMapsAPIKey"
            ) as? String,
            !apiKey.isEmpty,
            !apiKey.hasPrefix("$("),
            apiKey != "YOUR_GOOGLE_MAPS_API_KEY"
        else {
            return false
        }

        isConfigured = GMSServices.provideAPIKey(apiKey)
        GMSPlacesClient.provideAPIKey(apiKey)
        return isConfigured
    }
}
