//
//  PlaceSelectionFeature.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture
import CoreGraphics

struct PlaceSelectionFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var searchText = ""
        var isBottomSheetExpanded = true
        var isSearchPresented = false
        var selectedPlace: PlaceDetails?
        var isPlaceDetailsLoading = false
        var placeSearch = PlaceSearchFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case backButtonTapped
        case searchFieldTapped
        case searchTextChanged(String)
        case searchButtonTapped
        case dimmedBackgroundTapped
        case bottomSheetDragEnded(CGFloat)
        case clearSelectedPlaceButtonTapped
        case placeDetailsResponse(PlaceDetails)
        case placeDetailsFailed
        case searchDismissed
        case placeSearch(PlaceSearchFeature.Action)
    }

    @Dependency(\.placeClient) var placeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                return .none

            case .searchFieldTapped:
                state.isSearchPresented = true
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case .searchButtonTapped:
                state.isBottomSheetExpanded = false
                state.isSearchPresented = true
                return .none

            case .dimmedBackgroundTapped:
                state.isBottomSheetExpanded = false
                return .none

            case let .bottomSheetDragEnded(translation):
                guard state.selectedPlace == nil else { return .none }
                if translation > 40 {
                    state.isBottomSheetExpanded = false
                } else if translation < -40 {
                    state.isBottomSheetExpanded = true
                }
                return .none

            case .clearSelectedPlaceButtonTapped:
                state.searchText = ""
                state.selectedPlace = nil
                state.isPlaceDetailsLoading = false
                state.isBottomSheetExpanded = true
                return .none

            case let .placeDetailsResponse(details):
                state.selectedPlace = details
                state.isPlaceDetailsLoading = false
                return .none

            case .placeDetailsFailed:
                state.isPlaceDetailsLoading = false
                return .none

            case .searchDismissed, .placeSearch(.delegate(.close)):
                state.isSearchPresented = false
                return .none

            case let .placeSearch(.delegate(.placeSelected(result))):
                state.searchText = result.name
                state.isSearchPresented = false
                state.isBottomSheetExpanded = true
                state.isPlaceDetailsLoading = true
                state.selectedPlace = PlaceDetails(
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
                return .run { send in
                    do {
                        await send(.placeDetailsResponse(try await placeClient.fetchDetails(result)))
                    } catch {
                        await send(.placeDetailsFailed)
                    }
                }

            case .placeSearch:
                return .none
            }
        }

        Scope(state: \.placeSearch, action: \.placeSearch) {
            PlaceSearchFeature()
        }
    }
}
