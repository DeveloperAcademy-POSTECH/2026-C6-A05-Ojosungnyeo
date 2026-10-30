//
//  TripSearchFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct TripSearchFeature: Reducer {
    typealias Region = TripDestination.Region
    typealias City = TripDestination

    @ObservableState
    struct State: Equatable {
        var searchText = ""
        var selectedRegion: Region = .asia
        var selectedCityIDs: Set<City.ID> = []
        var selectedCityOrder: [City.ID] = []
        var cities: [City] = []
        var isLoading = false
        var errorMessage: String?
        var tripSetUp = TripSetUpFeature.State()
        var isTripSetUpPresented = false

        var filteredCities: [City] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            return cities.filter { city in
                guard city.region == selectedRegion else { return false }
                guard !query.isEmpty else { return true }
                return city.name.localizedCaseInsensitiveContains(query)
                    || city.country.localizedCaseInsensitiveContains(query)
            }
        }

        var selectedCities: [City] {
            var seenIDs: Set<City.ID> = []
            return (selectedCityOrder + cities.map(\.id)).compactMap { id in
                guard selectedCityIDs.contains(id), seenIDs.insert(id).inserted else {
                    return nil
                }
                return cities.first { $0.id == id }
            }
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case destinationsResponse([City])
        case destinationsFailed(String)
        case backButtonTapped
        case searchTextChanged(String)
        case regionFilterSelected(Region)
        case cityTapped(City.ID)
        case selectedCityRemoveButtonTapped(City.ID)
        case nextButtonTapped
        case tripSetUpDismissed
        case tripSetUp(TripSetUpFeature.Action)
    }

    @Dependency(\.destinationClient) var destinationClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.cities.isEmpty, !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        await send(.destinationsResponse(try await destinationClient.fetchDestinations()))
                    } catch {
                        await send(.destinationsFailed(error.localizedDescription))
                    }
                }

            case let .destinationsResponse(cities):
                state.cities = cities
                state.isLoading = false
                return .none

            case let .destinationsFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .backButtonTapped:
                return .none

            case .nextButtonTapped:
                let selectedCities = state.selectedCities
                guard !selectedCities.isEmpty else { return .none }
                state.tripSetUp = TripSetUpFeature.State(selectedCities: selectedCities)
                state.isTripSetUpPresented = true
                return .none

            case .tripSetUpDismissed, .tripSetUp(.backButtonTapped):
                state.isTripSetUpPresented = false
                return .none

            case .tripSetUp:
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case let .regionFilterSelected(region):
                state.selectedRegion = region
                return .none

            case let .cityTapped(cityID):
                if state.selectedCityIDs.contains(cityID) {
                    state.selectedCityIDs.remove(cityID)
                    state.selectedCityOrder.removeAll { $0 == cityID }
                } else {
                    state.selectedCityIDs.insert(cityID)
                    state.selectedCityOrder.append(cityID)
                }
                return .none

            case let .selectedCityRemoveButtonTapped(cityID):
                state.selectedCityIDs.remove(cityID)
                state.selectedCityOrder.removeAll { $0 == cityID }
                return .none
            }
        }

        Scope(state: \.tripSetUp, action: \.tripSetUp) {
            TripSetUpFeature()
        }
    }
}
