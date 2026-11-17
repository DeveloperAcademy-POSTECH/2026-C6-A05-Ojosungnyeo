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
        case placeAdded(PlaceDetails, TripDay, [TripMember])
    }

    @ObservableState
    struct State: Equatable {
        var search = PlaceSearchFeature.State()
        var selectedPlace: PlaceDetails?
        var isPlaceDetailsLoading = false
        var isDaySelectionPresented = false
        var isFriendSelectionPresented = false
        var availableDays: [TripDay] = [.day1]
        var tripMembers: [TripMember] = TripMember.allCases
        var currentMember: TripMember = .tae
        var selectedDay: TripDay?
        var selectedFriends: Set<TripMember> = []

        var availableFriends: [TripMember] {
            tripMembers.filter { $0 != currentMember }
        }
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
        case aloneButtonTapped
        case withFriendsButtonTapped
        case friendTapped(TripMember)
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
                state.selectedPlace = nil
                return .none

            case .detailBackButtonTapped, .detailCloseButtonTapped:
                state.selectedPlace = nil
                state.isPlaceDetailsLoading = false
                state.isDaySelectionPresented = false
                state.isFriendSelectionPresented = false
                state.selectedDay = nil
                state.selectedFriends = []
                return .none

            case .addButtonTapped:
                guard !state.isPlaceDetailsLoading,
                      state.selectedPlace != nil
                else { return .none }
                state.selectedDay = state.selectedDay ?? state.availableDays.first
                state.isDaySelectionPresented = true
                return .none

            case .daySelectionDismissed:
                state.isDaySelectionPresented = false
                state.isFriendSelectionPresented = false
                state.selectedDay = nil
                state.selectedFriends = []
                return .none

            case let .daySelected(day):
                guard !state.isPlaceDetailsLoading,
                      state.availableDays.contains(day),
                      state.selectedPlace != nil
                else { return .none }
                state.selectedDay = day
                return .none

            case .aloneButtonTapped:
                guard let place = state.selectedPlace,
                      let day = state.selectedDay
                else { return .none }
                state.isDaySelectionPresented = false
                return .send(.delegate(.placeAdded(place, day, [state.currentMember])))

            case .withFriendsButtonTapped:
                guard !state.availableFriends.isEmpty else { return .none }
                state.isFriendSelectionPresented = true
                return .none

            case let .friendTapped(member):
                guard let place = state.selectedPlace,
                      let day = state.selectedDay,
                      state.availableFriends.contains(member)
                else { return .none }
                state.selectedFriends = [member]
                let selectedMembers = state.tripMembers.filter {
                    $0 == state.currentMember || state.selectedFriends.contains($0)
                }
                state.isDaySelectionPresented = false
                state.isFriendSelectionPresented = false
                return .send(.delegate(.placeAdded(place, day, selectedMembers)))

            case .delegate:
                return .none
            }
        }

        Scope(state: \.search, action: \.search) {
            PlaceSearchFeature()
        }
    }
}
