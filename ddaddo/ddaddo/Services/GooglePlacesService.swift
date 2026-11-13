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
                    continuation.resume(
                        throwing: GooglePlacesServiceError.placeDetailsUnavailable(result.name)
                    )
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

    private static func categoryName(for types: [String]?) -> String {
        let placeTypes = Set(types ?? [])
        let categories: [(name: String, types: Set<String>)] = [
            ("맛집", ["restaurant", "meal_takeaway", "meal_delivery", "ramen_restaurant", "sushi_restaurant", "korean_restaurant", "japanese_restaurant"]),
            ("카페", ["cafe", "coffee_shop"]),
            ("디저트", ["bakery", "dessert_shop", "ice_cream_shop", "candy_store"]),
            ("바·펍", ["bar", "pub", "wine_bar", "cocktail_bar"]),
            ("시장", ["market", "supermarket", "grocery_store"]),
            ("기념품", ["gift_shop"]),
            ("쇼핑", ["shopping_mall", "department_store", "clothing_store", "shoe_store"]),
            ("편집숍", ["store", "home_goods_store", "furniture_store", "book_store"]),
            ("랜드마크", ["landmark", "monument", "cultural_landmark", "historical_landmark"]),
            ("전망대", ["observation_deck"]),
            ("역사·종교", ["church", "hindu_temple", "mosque", "synagogue", "buddhist_temple", "place_of_worship", "historical_place"]),
            ("박물관", ["museum"]),
            ("미술관", ["art_gallery"]),
            ("공연·전시", ["performing_arts_theater", "concert_hall", "event_venue", "convention_center"]),
            ("공방·체험", ["cultural_center", "community_center"]),
            ("공원·정원", ["park", "garden", "national_park"]),
            ("해변", ["beach"]),
            ("산·트레킹", ["hiking_area"]),
            ("호수·강", ["lake", "river", "natural_feature"]),
            ("테마파크", ["amusement_park", "water_park"]),
            ("동물원·수족관", ["zoo", "aquarium"]),
            ("게임·오락", ["bowling_alley", "casino", "movie_theater", "amusement_center", "video_arcade"]),
            ("온천·스파", ["spa", "sauna"]),
            ("숙소", ["lodging", "hotel", "motel", "hostel", "bed_and_breakfast", "guest_house"]),
            ("공항", ["airport"]),
            ("기차역", ["train_station", "subway_station"]),
            ("버스터미널", ["bus_station", "transit_station"]),
            ("관광지", ["tourist_attraction"])
        ]

        for category in categories {
            if !placeTypes.isDisjoint(with: category.types) {
                return category.name
            }
        }
        return "장소"
    }
}

private enum GooglePlacesServiceError: LocalizedError {
    case placeDetailsUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .placeDetailsUnavailable(placeName):
            "\(placeName)의 상세 장소 정보를 가져오지 못했어요."
        }
    }
}
