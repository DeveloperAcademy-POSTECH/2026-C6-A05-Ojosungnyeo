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
    static func configure() {
        guard
            let apiKey = Bundle.main.object(
                forInfoDictionaryKey: "GoogleMapsAPIKey"
            ) as? String,
            !apiKey.isEmpty,
            !apiKey.hasPrefix("$("),
            apiKey != "YOUR_GOOGLE_MAPS_API_KEY"
        else {
            return
        }

        GMSServices.provideAPIKey(apiKey)
        GMSPlacesClient.provideAPIKey(apiKey)
    }
}
