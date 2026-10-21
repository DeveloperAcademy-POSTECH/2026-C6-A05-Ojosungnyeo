//
//  PlaceSearchFeature.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture
import Foundation

struct PlaceSearchFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var searchText = ""
        var results: [PlaceSearchResult] = []
        var isLoading = false
        var errorMessage: String?
    }

    @CasePathable
    enum Action: Equatable {
        case closeButtonTapped
        case searchTextChanged(String)
        case searchResponse([PlaceSearchResult])
        case searchFailed(String)
        case resultTapped(PlaceSearchResult)
        case delegate(DelegateAction)
    }

    enum DelegateAction: Equatable {
        case close
        case placeSelected(PlaceSearchResult)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.placeClient) var placeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeButtonTapped:
                return .send(.delegate(.close))

            case let .searchTextChanged(text):
                state.searchText = text
                state.errorMessage = nil

                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else {
                    state.results = []
                    state.isLoading = false
                    return .cancel(id: "place-search")
                }

                state.isLoading = true
                return .run { send in
                    do {
                        try await clock.sleep(for: .milliseconds(300))
                        let results = try await placeClient.autocomplete(query)
                        await send(.searchResponse(results))
                    } catch is CancellationError {
                        return
                    } catch {
                        await send(.searchFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: "place-search", cancelInFlight: true)

            case let .searchResponse(results):
                state.results = results
                state.isLoading = false
                return .none

            case let .searchFailed(message):
                state.results = []
                state.isLoading = false
                state.errorMessage = message
                return .none

            case let .resultTapped(result):
                return .send(.delegate(.placeSelected(result)))

            case .delegate:
                return .none
            }
        }
    }
}
