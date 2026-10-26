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
        let thumbnailImageName: String
        let heroImageName: String
        let mapImageName: String
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
            return Self.mockAccommodations.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.address.localizedCaseInsensitiveContains(query)
            }
        }

        private static let mockAccommodations = [
            Accommodation(
                id: "tokyo-dome-hotel",
                name: "도쿄돔 호텔",
                address: "1-3-61 고라쿠, 분쿄구, 도쿄",
                website: "https://www.tokyodome-hotels.com",
                thumbnailImageName: "DDMockAccommodationThumbnail",
                heroImageName: "DDMockAccommodationHero",
                mapImageName: "DDMockAccommodationMap"
            ),
            Accommodation(
                id: "richmond-suidobashi",
                name: "리치몬드 호텔 도쿄 스이도바시",
                address: "1-33-9 혼고, 분쿄구, 도쿄",
                website: "https://richmondhotel.jp/suidobashi/",
                thumbnailImageName: "DDMockAccommodationThumbnail",
                heroImageName: "DDMockAccommodationHero",
                mapImageName: "DDMockAccommodationMap"
            ),
            Accommodation(
                id: "metropolitan-edmont",
                name: "호텔 메트로폴리탄 에드몬트",
                address: "3-10-8 이이다바시, 치요다구, 도쿄",
                website: "https://edmont.metropolitan.jp/",
                thumbnailImageName: "DDMockAccommodationThumbnail",
                heroImageName: "DDMockAccommodationHero",
                mapImageName: "DDMockAccommodationMap"
            ),
            Accommodation(
                id: "hotel-niwa-tokyo",
                name: "호텔 니와 도쿄",
                address: "1-1-16 간다미사키초, 치요다구, 도쿄",
                website: "https://www.hotelniwa.jp/",
                thumbnailImageName: "DDMockAccommodationThumbnail",
                heroImageName: "DDMockAccommodationHero",
                mapImageName: "DDMockAccommodationMap"
            )
        ]
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
