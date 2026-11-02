//
//  PlaceGroupingFeature.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

import ComposableArchitecture
import CoreLocation
import Foundation

struct PlaceGroupingFeature: Reducer {
    enum Tab: Equatable {
        case preferences
        case recommendedGroups
    }

    struct Member: Equatable, Identifiable {
        let id: String
        let name: String
        let preferences: String
        let avatar: ParticipantAvatar
    }

    struct RecommendedGroup: Equatable, Identifiable {
        let id: String
        let title: String
        let participantSummary: String
        let memberIDs: [String]
        let categories: [String]
        let places: [PinnedPlace]
    }

    @ObservableState
    struct State: Equatable {
        var tripTitle = PlaceGroupingPreviewData.tripTitle
        var tripDates = PlaceGroupingPreviewData.tripDates
        var travelCriteria = PlaceGroupingPreviewData.travelCriteria
        var selectedTab = Tab.preferences
        var members = PlaceGroupingPreviewData.members
        var placeGroups = PlaceGroupingPreviewData.placeGroups
        var recommendedGroups = PlaceGroupingPreviewData.recommendedGroups
        var currentMemberID = "juni"
        var confirmedGroupID: String?
        var selectedGroupID: String?
        var detail = PlaceGroupingDetailFeature.State()
        var isDetailPresented = false
        var isCriteriaChangeConfirmationPresented = false
        var waitingForConfirmation = WaitingForConfirmationFeature.State()
        var isWaitingForConfirmationPresented = false

        init() {}

        init(placeSelection: PlaceSelectionFeature.State) {
            let result = PlaceGroupingEngine.makeGroups(from: placeSelection)
            tripTitle = placeSelection.tripTitle
            tripDates = Self.dateText(
                start: placeSelection.tripStartDate,
                end: placeSelection.tripEndDate
            )
            travelCriteria = "대중교통 · 장소 간 최대 30분"
            members = result.members
            placeGroups = result.mapGroups
            recommendedGroups = result.recommendedGroups
            currentMemberID = placeSelection.currentMember.rawValue
            detail = PlaceGroupingDetailFeature.State()
        }

        private static func dateText(start: Date, end: Date) -> String {
            let calendar = Calendar.current
            let startParts = calendar.dateComponents([.month, .day], from: start)
            let endParts = calendar.dateComponents([.month, .day], from: end)
            return "\(startParts.month ?? 0)월 \(startParts.day ?? 0)일 ~ \(endParts.day ?? 0)일"
        }
    }

    @CasePathable
    enum Action: Equatable {
        case travelCriteriaChangeTapped
        case criteriaChangeCancelTapped
        case criteriaChangeConfirmTapped
        case tabSelected(Tab)
        case memberTapped(String)
        case recommendedGroupTapped(String)
        case detail(PlaceGroupingDetailFeature.Action)
        case confirmButtonTapped
        case waitingForConfirmation(WaitingForConfirmationFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .travelCriteriaChangeTapped:
                state.isCriteriaChangeConfirmationPresented = true
                return .none
            case .criteriaChangeCancelTapped:
                state.isCriteriaChangeConfirmationPresented = false
                return .none
            case .criteriaChangeConfirmTapped:
                state.isCriteriaChangeConfirmationPresented = false
                state.confirmedGroupID = nil
                state.selectedGroupID = nil
                return .none
            case .memberTapped:
                return .none
            case let .recommendedGroupTapped(id):
                guard let group = state.recommendedGroups.first(where: { $0.id == id }) else {
                    return .none
                }
                state.selectedGroupID = id
                state.detail = PlaceGroupingDetailFeature.State(
                    tripTitle: state.tripTitle,
                    tripDates: state.tripDates,
                    group: group,
                    allMembers: state.members,
                    currentMemberID: state.currentMemberID
                )
                state.isDetailPresented = true
                return .none
            case .detail(.delegate(.confirmed)):
                state.confirmedGroupID = state.selectedGroupID
                state.isDetailPresented = false
                return .none
            case .detail(.delegate(.joined)):
                state.confirmedGroupID = state.selectedGroupID
                state.isDetailPresented = false
                return .none
            case .detail(.backButtonTapped):
                state.isDetailPresented = false
                return .none
            case .detail:
                return .none
            case .confirmButtonTapped:
                state.isWaitingForConfirmationPresented = true
                return .none
            case .waitingForConfirmation(.backButtonTapped):
                state.isWaitingForConfirmationPresented = false
                return .none
            case .waitingForConfirmation:
                return .none
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            }
        }

        Scope(state: \.waitingForConfirmation, action: \.waitingForConfirmation) {
            WaitingForConfirmationFeature()
        }

        Scope(state: \.detail, action: \.detail) {
            PlaceGroupingDetailFeature()
        }
    }
}

private enum PlaceGroupingEngine {
    struct Result {
        let members: [PlaceGroupingFeature.Member]
        let mapGroups: [MapPlaceGroup]
        let recommendedGroups: [PlaceGroupingFeature.RecommendedGroup]
    }

    private struct OwnedPlace {
        let member: TripMember
        let place: PinnedPlace
    }

    static func makeGroups(from state: PlaceSelectionFeature.State) -> Result {
        let joined = state.participants.filter(\.hasJoined)
        let members = joined.map { participant in
            let categories = Set(
                state.memberPlaces[participant.member, default: []]
                    .map { normalizedCategory($0.category) }
            )
            return PlaceGroupingFeature.Member(
                id: participant.member.rawValue,
                name: participant.name,
                preferences: categories.isEmpty
                    ? "자유시간 · 합류 확인"
                    : categories.sorted().joined(separator: ", "),
                avatar: participant.member.avatar
            )
        }

        let ownedPlaces = joined.flatMap { participant in
            state.memberPlaces[participant.member, default: []].map {
                OwnedPlace(member: participant.member, place: $0)
            }
        }
        let regions = connectedRegions(ownedPlaces)
        let mapGroups = regions.enumerated().map { index, region in
            let uniquePlaces = unique(region.map(\.place))
            return MapPlaceGroup(
                id: "region-\(index)",
                name: regionName(for: uniquePlaces, destination: state.destinationName, index: index),
                places: uniquePlaces,
                radius: max(800, regionRadius(uniquePlaces) + 500)
            )
        }

        var recommendations: [PlaceGroupingFeature.RecommendedGroup] = []
        for (regionIndex, region) in regions.enumerated() {
            let regionPlaces = unique(region.map(\.place))
            let title = regionName(
                for: regionPlaces,
                destination: state.destinationName,
                index: regionIndex
            )
            let memberIDs = Array(Set(region.map { $0.member.rawValue })).sorted()
            let memberComponents = categoryConnectedMembers(memberIDs, region: region)

            for (componentIndex, component) in memberComponents.enumerated() {
                let componentSet = Set(component)
                let places = unique(
                    region.filter { componentSet.contains($0.member.rawValue) }.map(\.place)
                )
                let categorySets = component.map { memberID in
                    Set(region.filter { $0.member.rawValue == memberID }.map {
                        normalizedCategory($0.place.category)
                    })
                }
                let shared = categorySets.dropFirst().reduce(categorySets.first ?? []) {
                    $0.intersection($1)
                }
                let categories = shared.isEmpty
                    ? Array(Set(places.map { normalizedCategory($0.category) })).sorted()
                    : shared.sorted()
                let groupTitle = memberComponents.count == 1
                    ? title
                    : "\(title) \(componentIndex + 1)"
                recommendations.append(
                    .init(
                        id: "region-\(regionIndex)-group-\(componentIndex)",
                        title: groupTitle,
                        participantSummary: "\(component.count)명 · \(places.count)곳",
                        memberIDs: component,
                        categories: categories,
                        places: places
                    )
                )
            }
        }

        // 장소가 없는 사람도 자유시간/합류 확인 그룹으로 결과에 남긴다.
        let placedMemberIDs = Set(ownedPlaces.map { $0.member.rawValue })
        for participant in joined where !placedMemberIDs.contains(participant.member.rawValue) {
            recommendations.append(
                .init(
                    id: "free-\(participant.member.rawValue)",
                    title: "자유시간 · 합류 확인",
                    participantSummary: "\(participant.name) · 저장한 장소 없음",
                    memberIDs: [participant.member.rawValue],
                    categories: [],
                    places: []
                )
            )
        }

        return Result(
            members: members,
            mapGroups: mapGroups,
            recommendedGroups: recommendations
        )
    }

    private static func connectedRegions(_ places: [OwnedPlace]) -> [[OwnedPlace]] {
        var visited = Set<Int>()
        var result: [[OwnedPlace]] = []
        for start in places.indices where !visited.contains(start) {
            var queue = [start]
            visited.insert(start)
            var region: [OwnedPlace] = []
            while let index = queue.popLast() {
                region.append(places[index])
                for candidate in places.indices where !visited.contains(candidate) {
                    if distance(places[index].place, places[candidate].place) <= 5_500 {
                        visited.insert(candidate)
                        queue.append(candidate)
                    }
                }
            }
            result.append(region)
        }
        return result
    }

    private static func categoryConnectedMembers(
        _ members: [String],
        region: [OwnedPlace]
    ) -> [[String]] {
        var visited = Set<String>()
        var result: [[String]] = []
        let categories = Dictionary(uniqueKeysWithValues: members.map { member in
            (member, Set(region.filter { $0.member.rawValue == member }.map {
                normalizedCategory($0.place.category)
            }))
        })
        for start in members where !visited.contains(start) {
            var queue = [start]
            visited.insert(start)
            var component: [String] = []
            while let member = queue.popLast() {
                component.append(member)
                for candidate in members where !visited.contains(candidate) {
                    if !(categories[member, default: []]
                        .intersection(categories[candidate, default: []]).isEmpty) {
                        visited.insert(candidate)
                        queue.append(candidate)
                    }
                }
            }
            result.append(component.sorted())
        }
        return result
    }

    private static func normalizedCategory(_ raw: String) -> String {
        let value = raw.lowercased()
        if value.contains("카페") || value.contains("디저트") || value.contains("coffee") || value.contains("cafe") { return "카페" }
        if value.contains("맛집") || value.contains("음식") || value.contains("식당") || value.contains("restaurant") || value.contains("food") { return "맛집" }
        if value.contains("쇼핑") || value.contains("상점") || value.contains("store") || value.contains("shop") { return "쇼핑" }
        if value.contains("자연") || value.contains("공원") || value.contains("park") { return "자연" }
        if value.contains("문화") || value.contains("관광") || value.contains("미술") || value.contains("박물") || value.contains("temple") { return "문화" }
        return raw.isEmpty ? "기타" : raw
    }

    private static func distance(_ lhs: PinnedPlace, _ rhs: PinnedPlace) -> Double {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
    }

    private static func regionRadius(_ places: [PinnedPlace]) -> Double {
        guard !places.isEmpty else { return 800 }
        let latitude = places.map(\.latitude).reduce(0, +) / Double(places.count)
        let longitude = places.map(\.longitude).reduce(0, +) / Double(places.count)
        let center = CLLocation(latitude: latitude, longitude: longitude)
        return places.map {
            center.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
        }.max() ?? 800
    }

    private static func unique(_ places: [PinnedPlace]) -> [PinnedPlace] {
        var ids = Set<String>()
        return places.filter { ids.insert($0.id).inserted }
    }

    private static func regionName(
        for places: [PinnedPlace],
        destination: String,
        index: Int
    ) -> String {
        let text = places.map { "\($0.name) \($0.description)" }.joined(separator: " ").lowercased()
        if text.contains("shinjuku") || text.contains("신주쿠") { return "신주쿠" }
        if text.contains("shibuya") || text.contains("시부야") { return "시부야" }
        if text.contains("ginza") || text.contains("chuo") || text.contains("긴자") || text.contains("주오") { return "주오" }
        if text.contains("minato") || text.contains("미나토") { return "미나토" }
        return "\(destination) 지역 \(index + 1)"
    }
}
