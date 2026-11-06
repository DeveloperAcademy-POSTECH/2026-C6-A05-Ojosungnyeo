//
//  RouteEditorFeature.swift
//  ddaddo
//
//  Created by sun on 11/4/26.
//

import ComposableArchitecture
import Foundation

struct RouteEditorFeature: Reducer {
    enum Delegate: Equatable {
        case dismissed
        case placeAdded(PlaceDetails, TripDay)
    }

    @ObservableState
    struct State: Equatable {
        var search = PlaceSearchFeature.State()
        var selectedPlace: PlaceDetails?
        var isPlaceDetailsLoading = false
        var isDaySelectionPresented = false
        var availableDays: [TripDay] = [.day1]
    }

    @CasePathable
    enum Action: Equatable {
        case search(PlaceSearchFeature.Action)
        case placeDetailsResponse(PlaceDetails)
        case placeDetailsFailed
        case detailBackButtonTapped
        case detailCloseButtonTapped
        case addButtonTapped
        case daySelectionDismissed
        case daySelected(TripDay)
        case delegate(Delegate)
    }

    @Dependency(\.placeClient) var placeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .search(.delegate(.close)):
                return .send(.delegate(.dismissed))

            case let .search(.delegate(.placeSelected(result))):
                state.search.searchText = result.name
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
                state.isPlaceDetailsLoading = true
                return .run { send in
                    do {
                        await send(.placeDetailsResponse(try await placeClient.fetchDetails(result)))
                    } catch {
                        await send(.placeDetailsFailed)
                    }
                }

            case .search:
                return .none

            case let .placeDetailsResponse(details):
                state.selectedPlace = details
                state.isPlaceDetailsLoading = false
                return .none

            case .placeDetailsFailed:
                state.isPlaceDetailsLoading = false
                return .none

            case .detailBackButtonTapped, .detailCloseButtonTapped:
                state.selectedPlace = nil
                state.isPlaceDetailsLoading = false
                state.isDaySelectionPresented = false
                return .none

            case .addButtonTapped:
                guard state.selectedPlace != nil else { return .none }
                state.isDaySelectionPresented = true
                return .none

            case .daySelectionDismissed:
                state.isDaySelectionPresented = false
                return .none

            case let .daySelected(day):
                guard state.availableDays.contains(day),
                      let place = state.selectedPlace
                else { return .none }
                state.isDaySelectionPresented = false
                return .send(.delegate(.placeAdded(place, day)))

            case .delegate:
                return .none
            }
        }

        Scope(state: \.search, action: \.search) {
            PlaceSearchFeature()
        }
    }
}
