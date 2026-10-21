//
//  TripMember.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

enum TripMember: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case tae
    case header
    case grae
    case juni

    var id: Self { self }
}
