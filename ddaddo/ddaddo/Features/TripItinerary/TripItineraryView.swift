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

    var body: some View {
        TabView(
            selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.tabSelected($0)) }
            )
        ) {
            TimeTableView()
                .tabItem {
                    Label("plans", systemImage: "calendar")
                }
                .tag(TripItineraryFeature.Tab.dailyItinerary)

            RouteOverviewView(
                store: store.scope(
                    state: \.routeOverview,
                    action: \.routeOverview
                )
            )
                .tabItem {
                    Label("route", systemImage: "map.fill")
                }
                .tag(TripItineraryFeature.Tab.routeOverview)
        }
        .tint(DDColor.actionPrimary)
    }
}

#Preview {
    TripItineraryView(
        store: Store(initialState: TripItineraryFeature.State()) {
            TripItineraryFeature()
        }
    )
}
