//
//  TripSetUpAddAccommodationFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct TripSetUpAddAccommodationFeature: Reducer {
    struct Accommodation: Equatable, Identifiable {
        let id: String
        let name: String
        let address: String
        let website: String
        let latitude: Double
        let longitude: Double
        let thumbnailImageName: String
        let heroImageName: String
    }

    enum Step: Equatable {
        case search
        case detail
    }

    @ObservableState
    struct State: Equatable {
        var step: Step = .search
        var searchText = ""
        var selectedAccommodation: Accommodation?

        init(accommodation: Accommodation? = nil) {
            guard let accommodation else { return }
            step = .detail
            searchText = accommodation.name
            selectedAccommodation = accommodation
        }

        var isSearchEnabled: Bool {
            searchText.contains { !$0.isWhitespace }
        }

        var searchResults: [Accommodation] {
            guard isSearchEnabled else { return [] }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return TripSetUpAccommodationMockData.accommodations.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.address.localizedCaseInsensitiveContains(query)
            }
        }
    }

    enum Action: Equatable {
        case backButtonTapped
        case searchTextChanged(String)
        case searchButtonTapped
        case accommodationSelected(Accommodation.ID)
        case addAccommodationButtonTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction: Equatable {
        case dismiss
        case completed(Accommodation)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                if state.step == .detail {
                    state.step = .search
                    return .none
                }
                return .send(.delegate(.dismiss))

            case let .searchTextChanged(value):
                state.searchText = value
                return .none

            case .searchButtonTapped:
                guard state.isSearchEnabled else { return .none }
                state.searchText = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                return .none

            case let .accommodationSelected(id):
                guard let accommodation = state.searchResults.first(where: { $0.id == id }) else {
                    return .none
                }
                state.selectedAccommodation = accommodation
                state.step = .detail
                return .none

            case .addAccommodationButtonTapped:
                guard let accommodation = state.selectedAccommodation else { return .none }
                return .send(.delegate(.completed(accommodation)))

            case .delegate:
                return .none
            }
        }
    }
}
