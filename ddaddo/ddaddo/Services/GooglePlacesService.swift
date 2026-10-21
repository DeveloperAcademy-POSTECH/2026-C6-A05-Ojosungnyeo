//
//  GooglePlacesService.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

@preconcurrency import GooglePlaces
import UIKit

final class GooglePlacesService: @unchecked Sendable {
    private let client = GMSPlacesClient.shared()
    private let sessionToken = GMSAutocompleteSessionToken()

    func autocomplete(query: String) async throws -> [PlaceSearchResult] {
        let request = GMSAutocompleteRequest(query: query)
        request.sessionToken = sessionToken

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[PlaceSearchResult], Error>) in
            client.fetchAutocompleteSuggestions(from: request) { suggestions, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let results = (suggestions ?? []).compactMap { suggestion -> PlaceSearchResult? in
                    guard let place = suggestion.placeSuggestion else { return nil }
                    return PlaceSearchResult(
                        id: place.placeID,
                        name: place.attributedPrimaryText.string,
                        address: place.attributedSecondaryText?.string ?? ""
                    )
                }
                continuation.resume(returning: results)
            }
        }
    }

    func fetchDetails(for result: PlaceSearchResult) async throws -> PlaceDetails {
        let properties: [String] = [
            GMSPlaceProperty.name.rawValue,
            GMSPlaceProperty.placeID.rawValue,
            GMSPlaceProperty.formattedAddress.rawValue,
            GMSPlaceProperty.coordinate.rawValue,
            GMSPlaceProperty.rating.rawValue,
            GMSPlaceProperty.userRatingsTotal.rawValue,
            GMSPlaceProperty.types.rawValue,
            GMSPlaceProperty.photos.rawValue
        ]
        let request = GMSFetchPlaceRequest(
            placeID: result.id,
            placeProperties: properties,
            sessionToken: sessionToken
        )

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<PlaceDetails, Error>) in
            client.fetchPlace(with: request) { [client] place, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let place else {
                    continuation.resume(returning: Self.fallbackDetails(for: result))
                    return
                }

                let metadata = Array((place.photos ?? []).prefix(2))
                Self.loadPhotos(metadata, client: client) { photoData in
                    continuation.resume(
                        returning: PlaceDetails(
                            id: place.placeID ?? result.id,
                            name: place.name ?? result.name,
                            address: place.formattedAddress ?? result.address,
                            category: Self.categoryName(for: place.types),
                            rating: Double(place.rating),
                            ratingCount: Int(place.userRatingsTotal),
                            latitude: place.coordinate.latitude,
                            longitude: place.coordinate.longitude,
                            photoData: photoData
                        )
                    )
                }
            }
        }
    }

    private static func loadPhotos(
        _ metadata: [GMSPlacePhotoMetadata],
        client: GMSPlacesClient,
        completion: @escaping ([Data]) -> Void
    ) {
        guard let first = metadata.first else {
            completion([])
            return
        }

        let request = GMSFetchPhotoRequest(
            photoMetadata: first,
            maxSize: CGSize(width: 700, height: 500)
        )
        client.fetchPhoto(with: request) { image, _ in
            loadPhotos(Array(metadata.dropFirst()), client: client) { remaining in
                let current = image?.jpegData(compressionQuality: 0.9).map { [$0] } ?? []
                completion(current + remaining)
            }
        }
    }

    private static func fallbackDetails(for result: PlaceSearchResult) -> PlaceDetails {
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
    }

    private static func categoryName(for types: [String]?) -> String {
        let localizedNames = [
            "clothing_store": "의류점",
            "restaurant": "음식점",
            "cafe": "카페",
            "bakery": "베이커리",
            "bar": "바",
            "museum": "박물관",
            "tourist_attraction": "관광 명소",
            "shopping_mall": "쇼핑몰",
            "lodging": "숙소"
        ]
        for type in types ?? [] {
            if let name = localizedNames[type] {
                return name
            }
        }
        return "장소"
    }
}
