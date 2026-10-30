//
//  TripItineraryView.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture
import SwiftUI

struct TripItineraryView: View {
    let store: StoreOf<TripItineraryFeature>
    private let tabItems = TripItineraryTabItemFactory.makeItems()

    var body: some View {
        Group {
            switch store.selectedTab {
            case .dailyItinerary:
                TimeTableView(
                    store: store.scope(
                        state: \.timeTable,
                        action: \.timeTable
                    )
                )

            case .routeOverview:
                RouteOverviewView(
                    store: store.scope(
                        state: \.routeOverview,
                        action: \.routeOverview
                    )
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            itineraryTabBar
        }
    }

    private var itineraryTabBar: some View {
        DDCustomTabBar(
            items: tabItems,
            selection: store.selectedTab,
            onSelect: { store.send(.tabSelected($0)) }
        )
    }
}

#Preview {
    TripItineraryView(
        store: Store(initialState: TripItineraryFeature.State()) {
            TripItineraryFeature()
        }
    )
}
