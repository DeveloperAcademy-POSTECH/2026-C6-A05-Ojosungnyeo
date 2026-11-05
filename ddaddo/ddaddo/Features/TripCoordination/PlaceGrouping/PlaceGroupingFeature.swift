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
    enum Delegate: Equatable {
        case proceedToItinerary
        case reanalyzeGrouping
        case returnToUpcomingTrips
    }

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
        var transportationSelection = TripSetUpTransportationFeature.Selection(
            transportation: .publicTransit,
            duration: .thirtyMinutes
        )
        var transportationSheet = TripSetUpTransportationFeature.State()
        var isTransportationSheetPresented = false
        var requestedPlacePhotoIDs: Set<String> = []
        var sourcePlaceSelection: PlaceSelectionFeature.State?
        var selectedTab = Tab.preferences
        var members = PlaceGroupingPreviewData.members
        var placeGroups = PlaceGroupingPreviewData.placeGroups
        var recommendedGroups = PlaceGroupingPreviewData.recommendedGroups
        var currentMemberID = "juni"
        var confirmedGroupIDs: Set<String> = []
        var selectedGroupID: String?
        var detail = PlaceGroupingDetailFeature.State()
        var isDetailPresented = false
        var isCriteriaChangeConfirmationPresented = false
        var waitingForConfirmation = WaitingForConfirmationFeature.State()
        var isWaitingForConfirmationPresented = false

        var haveAllRecommendedGroupsConfirmed: Bool {
            !recommendedGroups.isEmpty
                && recommendedGroups.allSatisfy { confirmedGroupIDs.contains($0.id) }
        }

        init() {}

        init(
            placeSelection: PlaceSelectionFeature.State,
            transportationSelection: TripSetUpTransportationFeature.Selection = .init(
                transportation: .publicTransit,
                duration: .thirtyMinutes
            )
        ) {
            let result = PlaceGroupingEngine.makeGroups(
                from: placeSelection,
                selection: transportationSelection
            )
            sourcePlaceSelection = placeSelection
            self.transportationSelection = transportationSelection
            transportationSheet = TripSetUpTransportationFeature.State(
                selection: transportationSelection
            )
            tripTitle = placeSelection.tripTitle
            tripDates = Self.dateText(
                start: placeSelection.tripStartDate,
                end: placeSelection.tripEndDate
            )
            travelCriteria = "\(transportationSelection.transportation.title) · 장소 간 최대 \(transportationSelection.duration.rawValue)분"
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
        case onAppear
        case onDisappear
        case refreshMemberPlaces
        case memberPlacesResponse([MemberPlacePins])
        case memberPlacesFailed
        case placePhotoResponse(String, Data?)
        case backButtonTapped
        case travelCriteriaChangeTapped
        case criteriaChangeCancelTapped
        case criteriaChangeConfirmTapped
        case transportationSheetDismissed
        case transportationSheet(TripSetUpTransportationFeature.Action)
        case tabSelected(Tab)
        case memberTapped(String)
        case recommendedGroupTapped(String)
        case detail(PlaceGroupingDetailFeature.Action)
        case confirmButtonTapped
        case waitingForConfirmation(WaitingForConfirmationFeature.Action)
        case delegate(Delegate)
    }

    @Dependency(\.placeClient) var placeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                var effects = placePhotoEffects(state: &state)
                if let tripID = state.sourcePlaceSelection?.tripID {
                    effects.append(fetchMemberPlacesEffect(tripID: tripID))
                    effects.append(
                        observeMemberPlacesEffect(tripID: tripID)
                        .cancellable(id: "place-grouping-member-places", cancelInFlight: true)
                    )
                }
                return .merge(effects)

            case .onDisappear:
                return .cancel(id: "place-grouping-member-places")

            case .refreshMemberPlaces:
                guard let tripID = state.sourcePlaceSelection?.tripID else { return .none }
                return fetchMemberPlacesEffect(tripID: tripID)

            case let .memberPlacesResponse(memberPins):
                guard var source = state.sourcePlaceSelection else { return .none }
                for pins in memberPins {
                    source.memberPlaces[pins.member] = pins.places
                    if let index = source.participants.firstIndex(where: {
                        $0.member == pins.member
                    }) {
                        source.participants[index].isConfirmed = pins.isConfirmed
                    }
                }
                state.sourcePlaceSelection = source
                let refreshed = PlaceGroupingEngine.makeGroups(
                    from: source,
                    selection: state.transportationSelection
                )
                let photoDataByID = state.recommendedGroups
                    .flatMap(\.places)
                    .reduce(into: [String: [Data]]()) { result, place in
                        if !place.photoData.isEmpty { result[place.id] = place.photoData }
                    }
                let enrich: (PinnedPlace) -> PinnedPlace = { place in
                    guard let photoData = photoDataByID[place.id] else { return place }
                    return PinnedPlace(
                        id: place.id,
                        name: place.name,
                        description: place.description,
                        thumbnailName: place.thumbnailName,
                        category: place.category,
                        photoData: photoData,
                        latitude: place.latitude,
                        longitude: place.longitude
                    )
                }
                state.members = refreshed.members
                state.placeGroups = refreshed.mapGroups.map { group in
                    MapPlaceGroup(
                        id: group.id,
                        name: group.name,
                        places: group.places.map(enrich),
                        radius: group.radius
                    )
                }
                state.recommendedGroups = refreshed.recommendedGroups.map { group in
                    RecommendedGroup(
                        id: group.id,
                        title: group.title,
                        participantSummary: group.participantSummary,
                        memberIDs: group.memberIDs,
                        categories: group.categories,
                        places: group.places.map(enrich)
                    )
                }
                state.confirmedGroupIDs.formIntersection(state.recommendedGroups.map(\.id))
                return .merge(placePhotoEffects(state: &state))

            case .memberPlacesFailed:
                return .none

            case let .placePhotoResponse(placeID, data):
                guard let data else { return .none }
                let updatePlace: (PinnedPlace) -> PinnedPlace = { place in
                    guard place.id == placeID else { return place }
                    return PinnedPlace(
                        id: place.id,
                        name: place.name,
                        description: place.description,
                        thumbnailName: "",
                        category: place.category,
                        photoData: [data],
                        latitude: place.latitude,
                        longitude: place.longitude
                    )
                }
                state.recommendedGroups = state.recommendedGroups.map { group in
                    RecommendedGroup(
                        id: group.id,
                        title: group.title,
                        participantSummary: group.participantSummary,
                        memberIDs: group.memberIDs,
                        categories: group.categories,
                        places: group.places.map(updatePlace)
                    )
                }
                state.placeGroups = state.placeGroups.map { group in
                    MapPlaceGroup(
                        id: group.id,
                        name: group.name,
                        places: group.places.map(updatePlace),
                        radius: group.radius
                    )
                }
                if var source = state.sourcePlaceSelection {
                    for member in source.memberPlaces.keys {
                        source.memberPlaces[member] = source.memberPlaces[member, default: []]
                            .map(updatePlace)
                    }
                    state.sourcePlaceSelection = source
                }
                state.detail.places = state.detail.places.map { place in
                    guard place.id == placeID else { return place }
                    var place = place
                    place.photoData = data
                    return place
                }
                return .none

            case .backButtonTapped:
                return .send(.delegate(.returnToUpcomingTrips))

            case .travelCriteriaChangeTapped:
                state.isCriteriaChangeConfirmationPresented = true
                return .none

            case .criteriaChangeCancelTapped:
                state.isCriteriaChangeConfirmationPresented = false
                return .none

            case .criteriaChangeConfirmTapped:
                state.isCriteriaChangeConfirmationPresented = false
                state.transportationSheet = TripSetUpTransportationFeature.State(
                    selection: state.transportationSelection
                )
                state.isTransportationSheetPresented = true
                return .none
            case .transportationSheetDismissed,
                 .transportationSheet(.delegate(.dismiss)):
                state.isTransportationSheetPresented = false
                return .none
            case let .transportationSheet(.delegate(.completed(selection))):
                state.isTransportationSheetPresented = false
                state.transportationSelection = selection
                state.travelCriteria = "\(selection.transportation.title) · 장소 간 최대 \(selection.duration.rawValue)분"
                guard let source = state.sourcePlaceSelection else { return .none }
                let refreshed = State(
                    placeSelection: source,
                    transportationSelection: selection
                )
                state.members = refreshed.members
                state.placeGroups = refreshed.placeGroups
                state.recommendedGroups = refreshed.recommendedGroups
                state.confirmedGroupIDs = []
                state.selectedGroupID = nil
                return .send(.delegate(.reanalyzeGrouping))
            case .transportationSheet:
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
                if let selectedGroupID = state.selectedGroupID {
                    state.confirmedGroupIDs.insert(selectedGroupID)
                }
                state.isDetailPresented = false
                return .none
            case .detail(.delegate(.joined)):
                if let selectedGroupID = state.selectedGroupID {
                    state.confirmedGroupIDs.insert(selectedGroupID)
                }
                state.isDetailPresented = false
                return .none
            case let .detail(.delegate(.placeDeleted(placeID))):
                guard let selectedGroupID = state.selectedGroupID else { return .none }
                state.recommendedGroups = state.recommendedGroups.map { group in
                    guard group.id == selectedGroupID else { return group }
                    return RecommendedGroup(
                        id: group.id,
                        title: group.title,
                        participantSummary: group.participantSummary,
                        memberIDs: group.memberIDs,
                        categories: group.categories,
                        places: group.places.filter { $0.id != placeID }
                    )
                }
                state.placeGroups = state.placeGroups.map { group in
                    guard group.id == selectedGroupID else { return group }
                    return MapPlaceGroup(
                        id: group.id,
                        name: group.name,
                        places: group.places.filter { $0.id != placeID },
                        radius: group.radius
                    )
                }
                return .none
            case let .detail(.delegate(.placesReordered(placeIDs))):
                guard let selectedGroupID = state.selectedGroupID else { return .none }
                let orderByID = Dictionary(
                    uniqueKeysWithValues: placeIDs.enumerated().map { ($1, $0) }
                )
                let reorder: ([PinnedPlace]) -> [PinnedPlace] = { places in
                    places.sorted {
                        orderByID[$0.id, default: Int.max]
                            < orderByID[$1.id, default: Int.max]
                    }
                }
                state.recommendedGroups = state.recommendedGroups.map { group in
                    guard group.id == selectedGroupID else { return group }
                    return RecommendedGroup(
                        id: group.id,
                        title: group.title,
                        participantSummary: group.participantSummary,
                        memberIDs: group.memberIDs,
                        categories: group.categories,
                        places: reorder(group.places)
                    )
                }
                state.placeGroups = state.placeGroups.map { group in
                    guard group.id == selectedGroupID else { return group }
                    return MapPlaceGroup(
                        id: group.id,
                        name: group.name,
                        places: reorder(group.places),
                        radius: group.radius
                    )
                }
                return .none
            case .detail(.backButtonTapped):
                state.isDetailPresented = false
                return .none
            case .detail:
                return .none
            case .confirmButtonTapped:
                guard state.haveAllRecommendedGroupsConfirmed else { return .none }
                guard let source = state.sourcePlaceSelection else { return .none }
                state.waitingForConfirmation = WaitingForConfirmationFeature.State(
                    tripID: source.tripID,
                    tripTitle: state.tripTitle,
                    tripDates: state.tripDates,
                    members: state.members,
                    currentMemberID: state.currentMemberID
                )
                state.isWaitingForConfirmationPresented = true
                let tripID = source.tripID
                let groupIDs = state.confirmedGroupIDs.sorted()
                return .run { _ in
                    try? await placeClient.confirmGroups(tripID, groupIDs)
                }
            case .waitingForConfirmation(.backButtonTapped):
                state.isWaitingForConfirmationPresented = false
                return .none
            case .waitingForConfirmation(.delegate(.proceedToItinerary)):
                state.isWaitingForConfirmationPresented = false
                return .send(.delegate(.proceedToItinerary))
            case .waitingForConfirmation:
                return .none
            case .delegate:
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

        Scope(state: \.transportationSheet, action: \.transportationSheet) {
            TripSetUpTransportationFeature()
        }
    }

    private func fetchMemberPlacesEffect(tripID: String) -> Effect<Action> {
        .run { send in
            do {
                let memberPlaces = try await placeClient.fetchMemberPlaces(tripID)
                await send(.memberPlacesResponse(memberPlaces))
            } catch {
                await send(.memberPlacesFailed)
            }
        }
    }

    private func observeMemberPlacesEffect(tripID: String) -> Effect<Action> {
        let stream = placeClient.observeMemberPlaces(tripID)
        return .run { send in
            do {
                for try await memberPlaces in stream {
                    await send(.memberPlacesResponse(memberPlaces))
                }
            } catch {
                await send(.memberPlacesFailed)
            }
        }
    }

    private func placePhotoEffects(state: inout State) -> [Effect<Action>] {
        let placesByID = state.recommendedGroups
            .flatMap(\.places)
            .reduce(into: [String: PinnedPlace]()) { result, place in
                result[place.id] = place
            }
        let placesNeedingPhotos = placesByID.values.filter { place in
            place.photoData.isEmpty
                && place.thumbnailName.isEmpty
                && !state.requestedPlacePhotoIDs.contains(place.id)
        }
        state.requestedPlacePhotoIDs.formUnion(placesNeedingPhotos.map(\.id))

        return placesNeedingPhotos.map { place in
            .run { send in
                do {
                    let result = PlaceSearchResult(
                        id: place.id,
                        name: place.name,
                        address: place.description
                    )
                    let details = try await placeClient.fetchDetails(result)
                    await send(.placePhotoResponse(place.id, details.photoData.first))
                } catch {
                    await send(.placePhotoResponse(place.id, nil))
                }
            }
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

    static func makeGroups(
        from state: PlaceSelectionFeature.State,
        selection: TripSetUpTransportationFeature.Selection
    ) -> Result {
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
        let regions = connectedRegions(
            ownedPlaces,
            maximumDistance: maximumDistance(for: selection)
        )
        let mapGroups = regions.enumerated().map { index, region in
            let uniquePlaces = unique(region.map(\.place))
            return MapPlaceGroup(
                id: "region-\(index)",
                name: regionName(destination: state.destinationName, index: index),
                places: uniquePlaces,
                radius: max(800, regionRadius(uniquePlaces) + 500)
            )
        }

        var recommendations: [PlaceGroupingFeature.RecommendedGroup] = []
        for (regionIndex, region) in regions.enumerated() {
            let regionPlaces = unique(region.map(\.place))
            let title = regionName(
                destination: state.destinationName,
                index: regionIndex
            )
            let memberIDs = Array(Set(region.map { $0.member.rawValue })).sorted()
            let memberComponents = categoryConnectedMembers(memberIDs, region: region)
            let categories = Array(Set(regionPlaces.map {
                normalizedCategory($0.category)
            })).sorted()
            recommendations.append(
                .init(
                    id: "region-\(regionIndex)",
                    title: title,
                    participantSummary: memberComponents
                        .map { "\($0.count)명" }
                        .joined(separator: " · "),
                    memberIDs: memberIDs,
                    categories: categories,
                    places: regionPlaces
                )
            )
        }

        return Result(
            members: members,
            mapGroups: mapGroups,
            recommendedGroups: recommendations
        )
    }

    private static func connectedRegions(
        _ places: [OwnedPlace],
        maximumDistance: Double
    ) -> [[OwnedPlace]] {
        var visited = Set<Int>()
        var result: [[OwnedPlace]] = []
        for start in places.indices where !visited.contains(start) {
            var queue = [start]
            visited.insert(start)
            var region: [OwnedPlace] = []
            while let index = queue.popLast() {
                region.append(places[index])
                for candidate in places.indices where !visited.contains(candidate) {
                    if distance(places[index].place, places[candidate].place) <= maximumDistance {
                        visited.insert(candidate)
                        queue.append(candidate)
                    }
                }
            }
            result.append(region)
        }
        return result
    }

    private static func maximumDistance(
        for selection: TripSetUpTransportationFeature.Selection
    ) -> Double {
        let metersPerMinute: Double = selection.transportation == .publicTransit ? 183 : 500
        return Double(selection.duration.rawValue) * metersPerMinute
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

    private static func regionName(destination: String, index: Int) -> String {
        "\(destination) 지역 \(index + 1)"
    }
}
