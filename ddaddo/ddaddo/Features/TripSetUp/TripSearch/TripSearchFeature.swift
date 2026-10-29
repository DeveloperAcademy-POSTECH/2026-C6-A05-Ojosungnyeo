//
//  TripSearchFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct TripSearchFeature: Reducer {
    enum Region: String, CaseIterable, Equatable {
        case asia = "아시아"
        case southeastAsia = "동남아"
        case europe = "유럽"
        case americasAndOceania = "미주/오세아니아"
    }

    struct City: Equatable, Identifiable {
        let id: String
        let country: String
        let name: String
        let region: Region
        let thumbnailName: String
    }

    @ObservableState
    struct State: Equatable {
        var searchText = ""
        var selectedRegion: Region = .asia
        var selectedCityIDs: Set<City.ID> = []
        var selectedCityOrder: [City.ID] = []
        var cities = TripSearchMockData.cities
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
        case backButtonTapped
        case searchTextChanged(String)
        case regionFilterSelected(Region)
        case cityTapped(City.ID)
        case selectedCityRemoveButtonTapped(City.ID)
        case nextButtonTapped
        case tripSetUpDismissed
        case tripSetUp(TripSetUpFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
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
