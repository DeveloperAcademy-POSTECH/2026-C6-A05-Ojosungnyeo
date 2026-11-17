import Foundation

enum GoogleRoutesService {
    private static let endpoint = URL(
        string: "https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix"
    )!
    private static let maximumMatrixSide = 10

    static func fetchTravelTimes(
        places: [PinnedPlace],
        transportation: Transportation
    ) async throws -> RouteTravelTimeMatrix {
        let uniquePlaces = places.reduce(into: [PinnedPlace]()) { result, place in
            guard !result.contains(where: { $0.id == place.id }) else { return }
            result.append(place)
        }
        guard uniquePlaces.count > 1 else {
            return RouteTravelTimeMatrix(durationsByOriginID: [:])
        }

        guard let apiKey = Bundle.main.object(
            forInfoDictionaryKey: "GoogleMapsAPIKey"
        ) as? String,
              !apiKey.isEmpty,
              !apiKey.hasPrefix("$(")
        else {
            throw GoogleRoutesError.missingAPIKey
        }

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let chunks = uniquePlaces.chunked(into: maximumMatrixSide)
        var durations: [String: [String: TimeInterval]] = [:]

        for origins in chunks {
            for destinations in chunks {
                let elements = try await fetchMatrix(
                    origins: origins,
                    destinations: destinations,
                    transportation: transportation,
                    apiKey: apiKey,
                    bundleIdentifier: bundleIdentifier
                )
                for element in elements where element.condition == "ROUTE_EXISTS" {
                    guard origins.indices.contains(element.originIndex),
                          destinations.indices.contains(element.destinationIndex),
                          let duration = Self.duration(from: element.duration)
                    else { continue }
                    let originID = origins[element.originIndex].id
                    let destinationID = destinations[element.destinationIndex].id
                    durations[originID, default: [:]][destinationID] = duration
                }
            }
        }

        return RouteTravelTimeMatrix(durationsByOriginID: durations)
    }

    private static func fetchMatrix(
        origins: [PinnedPlace],
        destinations: [PinnedPlace],
        transportation: Transportation,
        apiKey: String,
        bundleIdentifier: String
    ) async throws -> [RouteMatrixElement] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "originIndex,destinationIndex,duration,status,condition",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        if !bundleIdentifier.isEmpty {
            request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "origins": origins.map(routeMatrixLocation),
            "destinations": destinations.map(routeMatrixLocation),
            "travelMode": transportation == .publicTransit ? "TRANSIT" : "DRIVE"
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw GoogleRoutesError.invalidResponse
        }
        return try JSONDecoder().decode([RouteMatrixElement].self, from: data)
    }

    private static func routeMatrixLocation(_ place: PinnedPlace) -> [String: Any] {
        [
            "waypoint": [
                "location": [
                    "latLng": [
                        "latitude": place.latitude,
                        "longitude": place.longitude
                    ]
                ]
            ]
        ]
    }

    private static func duration(from value: String?) -> TimeInterval? {
        guard let value, value.hasSuffix("s") else { return nil }
        return TimeInterval(value.dropLast())
    }

    private struct RouteMatrixElement: Decodable {
        let originIndex: Int
        let destinationIndex: Int
        let duration: String?
        let condition: String?
    }

    private enum GoogleRoutesError: Error {
        case missingAPIKey
        case invalidResponse
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
