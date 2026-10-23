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
        var cities = Self.mockCities

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
            cities.filter { selectedCityIDs.contains($0.id) }
        }

        private static let mockCities: [City] = [
            City(
                id: "osaka",
                country: "일본",
                name: "오사카",
                region: .asia,
                thumbnailName: "DDTripSearchOsaka"
            ),
            City(
                id: "kyoto",
                country: "일본",
                name: "교토",
                region: .asia,
                thumbnailName: "DDTripSearchKyoto"
            ),
            City(
                id: "tokyo",
                country: "일본",
                name: "도쿄",
                region: .asia,
                thumbnailName: "DDTripSearchTokyo"
            ),
            City(
                id: "fukuoka",
                country: "일본",
                name: "후쿠오카",
                region: .asia,
                thumbnailName: "DDTripSearchFukuoka"
            ),
            City(
                id: "sapporo",
                country: "일본",
                name: "삿포로",
                region: .asia,
                thumbnailName: "DDTripSearchSapporo"
            )
        ]
    }

    enum Action: Equatable {
        case backButtonTapped
        case searchTextChanged(String)
        case regionFilterSelected(Region)
        case cityTapped(City.ID)
        case selectedCityRemoveButtonTapped(City.ID)
        case nextButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped, .nextButtonTapped:
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
                } else {
                    state.selectedCityIDs.insert(cityID)
                }
                return .none

            case let .selectedCityRemoveButtonTapped(cityID):
                state.selectedCityIDs.remove(cityID)
                return .none
            }
        }
    }
}
