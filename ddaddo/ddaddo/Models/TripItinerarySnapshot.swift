//
//  TripItinerarySnapshot.swift
//  ddaddo
//

import Foundation

struct TripItinerarySaveRequest: Equatable, Sendable {
    struct Course: Equatable, Sendable {
        let id: Int
        let title: String
        let placeNames: [String]
        let categories: [String]
        let memberIDs: [String]
        let durationMinutes: Int
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
