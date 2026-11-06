//
//  TripItineraryTabItemFactory.swift
//  ddaddo
//
//  Created by sun on 10/29/26.
//

enum TripItineraryTabItemFactory {
    static func makeItems() -> [DDTabBarItem<TripItineraryFeature.Tab>] {
        [
            DDTabBarItem(
                id: .dailyItinerary,
                title: "plans",
                iconName: "DDTabCalendar"
            ),
            DDTabBarItem(
                id: .routeOverview,
                title: "route",
                iconName: "DDTabRoute"
            )
        ]
    }
}
