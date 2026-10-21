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
        case searchDismissed
        case placeSearch(PlaceSearchFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                return .none

            case .searchFieldTapped:
                state.isBottomSheetExpanded = false
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
                if translation > 40 {
                    state.isBottomSheetExpanded = false
                } else if translation < -40 {
                    state.isBottomSheetExpanded = true
                }
                return .none

            case .searchDismissed, .placeSearch(.delegate(.close)):
                state.isSearchPresented = false
                return .none

            case let .placeSearch(.delegate(.placeSelected(result))):
                state.searchText = result.name
                state.isSearchPresented = false
                return .none

            case .placeSearch:
                return .none
            }
        }

        Scope(state: \.placeSearch, action: \.placeSearch) {
            PlaceSearchFeature()
        }
    }
}
