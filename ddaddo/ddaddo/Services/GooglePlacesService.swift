//
//  GooglePlacesService.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

@preconcurrency import GooglePlaces

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
}
