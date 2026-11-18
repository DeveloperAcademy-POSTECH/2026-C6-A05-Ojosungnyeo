import ComposableArchitecture

struct MapClient: DependencyKey, Sendable {
    var fetchTravelTimes: @Sendable (
        [PinnedPlace],
        Transportation
    ) async throws -> RouteTravelTimeMatrix

    static let liveValue = MapClient { places, transportation in
        try await GoogleRoutesService.fetchTravelTimes(
            places: places,
            transportation: transportation
        )
    }

    static let testValue = MapClient { _, _ in
        RouteTravelTimeMatrix(durationsByOriginID: [:])
    }
}

extension DependencyValues {
    var mapClient: MapClient {
        get { self[MapClient.self] }
        set { self[MapClient.self] = newValue }
    }
}
