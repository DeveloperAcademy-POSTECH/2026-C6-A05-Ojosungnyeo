//
//  TripItinerarySnapshot.swift
//  ddaddo
//

import Foundation

struct ItineraryPlace: Equatable, Sendable {
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
}

struct TripItinerarySaveRequest: Equatable, Sendable {
    struct Course: Equatable, Sendable {
        let id: Int
        let title: String
        let placeNames: [String]
        let categories: [String]
        let memberIDs: [String]
        let durationMinutes: Int
        let places: [ItineraryPlace]

        init(
            id: Int,
            title: String,
            placeNames: [String],
            categories: [String],
            memberIDs: [String],
            durationMinutes: Int,
            places: [ItineraryPlace] = []
        ) {
            self.id = id
            self.title = title
            self.placeNames = placeNames
            self.categories = categories
            self.memberIDs = memberIDs
            self.durationMinutes = durationMinutes
            self.places = places
        }
    }

    struct Schedule: Equatable, Sendable {
        let id: Int
        let courseID: Int
        let day: String
        let startMinuteOfDay: Int
        let branchGroupID: Int?
    }

    let tripID: String
    let courses: [Course]
    let schedules: [Schedule]
}

struct TripItinerarySnapshot: Equatable, Sendable {
    let courses: [TripItinerarySaveRequest.Course]
    let schedules: [TripItinerarySaveRequest.Schedule]
}
