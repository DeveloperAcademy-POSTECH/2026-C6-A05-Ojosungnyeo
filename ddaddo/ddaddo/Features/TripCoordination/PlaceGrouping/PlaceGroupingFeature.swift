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
        var joinedMemberIDsByGroupID: [String: Set<String>] = [:]
        var deletedPlaceIDsByGroupID: [String: Set<String>] = [:]
        var orderedPlaceIDsByGroupID: [String: [String]] = [:]
        var processedGroupEditEventIDs: Set<String> = []
        var processedGroupingConfigurationEventIDs: Set<String> = []
        var hasLoadedGroupingConfiguration = false
        var confirmedGroupIDsByMemberID: [String: Set<String>] = [:]
        var hasLoadedServerGroupConfirmations = false
        var confirmedGroupIDs: Set<String> = []
        var cancellationNotice: PlaceGroupingDetailFeature.CancellationNotice?
        var selectedGroupID: String?
        var detail = PlaceGroupingDetailFeature.State()
        var isDetailPresented = false
        var isCriteriaChangeConfirmationPresented = false
        var waitingForConfirmation = WaitingForConfirmationFeature.State()
        var isWaitingForConfirmationPresented = false
        var isRouteGroupingLoading = false

        var haveAllRecommendedGroupsConfirmed: Bool {
            !recommendedGroups.isEmpty
                && recommendedGroups.allSatisfy { confirmedGroupIDs.contains($0.id) }
        }

        var hasConfirmedRecommendedGroup: Bool {
            recommendedGroups.contains { confirmedGroupIDs.contains($0.id) }
        }

        var confirmedRecommendedGroupCount: Int {
            recommendedGroups.count { confirmedGroupIDs.contains($0.id) }
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
        case routeTravelTimesResponse(RouteTravelTimeMatrix)
        case routeTravelTimesFailed
        case groupMembershipsResponse([MemberGroupMembership])
        case groupMembershipsFailed
        case groupConfirmationsResponse([MemberGroupConfirmation])
        case groupConfirmationsFailed
        case cancellationNoticeDismissed
        case placePhotoResponse(String, Data?)
        case backButtonTapped
        case travelCriteriaChangeTapped
        case criteriaChangeCancelTapped
        case criteriaChangeConfirmTapped
        case transportationSheetDismissed
        case transportationSheet(TripSetUpTransportationFeature.Action)
        case tabSelected(Tab)
        case selectAllRecommendedGroupsTapped
        case memberTapped(String)
        case recommendedGroupTapped(String)
        case detail(PlaceGroupingDetailFeature.Action)
        case confirmButtonTapped
        case waitingForConfirmation(WaitingForConfirmationFeature.Action)
        case delegate(Delegate)
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.mapClient) var mapClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                var effects = placePhotoEffects(state: &state)
                if let tripID = state.sourcePlaceSelection?.tripID {
                    effects.append(fetchMemberPlacesEffect(tripID: tripID))
                    effects.append(fetchGroupConfirmationsEffect(tripID: tripID))
                    effects.append(
                        observeMemberPlacesEffect(tripID: tripID)
                        .cancellable(id: "place-grouping-member-places", cancelInFlight: true)
                    )
                    effects.append(
                        observeGroupMembershipsEffect(tripID: tripID)
                            .cancellable(id: "place-grouping-memberships", cancelInFlight: true)
                    )
                }
                effects.append(routeGroupingEffect(for: &state))
                return .merge(effects)

            case .onDisappear:
                return .merge(
                    .cancel(id: "place-grouping-member-places"),
                    .cancel(id: "place-grouping-memberships"),
                    .cancel(id: "route-grouping")
                )

            case .refreshMemberPlaces:
                guard let tripID = state.sourcePlaceSelection?.tripID else { return .none }
                return fetchMemberPlacesEffect(tripID: tripID)

            case let .memberPlacesResponse(memberPins):
                guard var source = state.sourcePlaceSelection else { return .none }
                var havePlacesChanged = false
                var hasParticipantStatusChanged = false
                for pins in memberPins {
                    if placeIdentitySet(source.memberPlaces[pins.member, default: []])
                        != placeIdentitySet(pins.places) {
                        source.memberPlaces[pins.member] = pins.places
                        havePlacesChanged = true
                    }
                    if let index = source.participants.firstIndex(where: {
                        $0.member == pins.member
                    }), source.participants[index].isConfirmed != pins.isConfirmed {
                        source.participants[index].isConfirmed = pins.isConfirmed
                        hasParticipantStatusChanged = true
                    }
                }
                guard havePlacesChanged || hasParticipantStatusChanged else { return .none }
                state.sourcePlaceSelection = source
                guard havePlacesChanged else { return .none }
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
                state.applyJoinedGroupMemberships()
                state.applyDeletedGroupPlaces()
                state.applyGroupPlaceOrders()
                state.confirmedGroupIDs.formIntersection(state.recommendedGroups.map(\.id))
                var effects = placePhotoEffects(state: &state)
                effects.append(routeGroupingEffect(for: &state))
                return .merge(effects)

            case .memberPlacesFailed:
                return .none

            case let .routeTravelTimesResponse(travelTimes):
                state.isRouteGroupingLoading = false
                guard let source = state.sourcePlaceSelection else { return .none }
                state.applyGroupingResult(
                    PlaceGroupingEngine.makeGroups(
                        from: source,
                        selection: state.transportationSelection,
                        travelTimes: travelTimes
                    )
                )
                return .merge(placePhotoEffects(state: &state))

            case .routeTravelTimesFailed:
                state.isRouteGroupingLoading = false
                return .none

            case let .groupMembershipsResponse(memberships):
                state.joinedMemberIDsByGroupID = memberships.reduce(into: [:]) { result, membership in
                    for groupID in membership.groupIDs {
                        result[groupID, default: []].insert(membership.member.rawValue)
                    }
                }
                state.applyJoinedGroupMemberships()
                state.deletedPlaceIDsByGroupID = memberships.reduce(into: [:]) { result, membership in
                    for (groupID, placeIDs) in membership.deletedPlaceIDsByGroupID {
                        result[groupID, default: []].formUnion(placeIDs)
                    }
                }
                state.applyDeletedGroupPlaces()
                state.orderedPlaceIDsByGroupID = memberships.reduce(into: [:]) { result, membership in
                    for (groupID, placeIDs) in membership.orderedPlaceIDsByGroupID {
                        result[groupID] = placeIDs
                    }
                }
                state.applyGroupPlaceOrders()

                let configurationEvents = memberships.compactMap(\.latestGroupingConfiguration)
                if !state.hasLoadedGroupingConfiguration {
                    state.hasLoadedGroupingConfiguration = true
                    state.processedGroupingConfigurationEventIDs.formUnion(
                        configurationEvents.map(\.id)
                    )
                    if let latestConfiguration = configurationEvents.max(by: {
                        $0.createdAt < $1.createdAt
                    }) {
                        state.applyGroupingConfiguration(latestConfiguration)
                    }
                } else if let latestConfiguration = configurationEvents
                    .filter({
                        !state.processedGroupingConfigurationEventIDs.contains($0.id)
                            && $0.editor.rawValue != state.currentMemberID
                    })
                    .max(by: { $0.createdAt < $1.createdAt }) {
                    state.processedGroupingConfigurationEventIDs.formUnion(
                        configurationEvents.map(\.id)
                    )
                    state.applyGroupingConfiguration(latestConfiguration)
                    return .send(.delegate(.reanalyzeGrouping))
                }

                let latestConfirmations = Dictionary(uniqueKeysWithValues: memberships.map {
                    ($0.member.rawValue, Set($0.confirmedGroupIDs))
                })
                state.confirmedGroupIDsByMemberID = latestConfirmations
                let latestEditEvents = memberships.compactMap(\.latestGroupEdit)
                guard state.hasLoadedServerGroupConfirmations else {
                    state.hasLoadedServerGroupConfirmations = true
                    state.confirmedGroupIDs = latestConfirmations[state.currentMemberID, default: []]
                    state.processedGroupEditEventIDs.formUnion(latestEditEvents.map(\.id))
                    return .none
                }

                let newEditEvents = latestEditEvents.filter {
                    !state.processedGroupEditEventIDs.contains($0.id)
                }
                state.processedGroupEditEventIDs.formUnion(newEditEvents.map(\.id))
                let otherMemberEdits = newEditEvents.filter {
                    $0.editor.rawValue != state.currentMemberID
                }
                let editedGroupIDs = Set(otherMemberEdits.map(\.groupID))
                let cancelledGroupIDs = state.confirmedGroupIDs.intersection(editedGroupIDs)
                let selectedGroupWasConfirmed = state.detail.isGroupConfirmed

                state.confirmedGroupIDs.subtract(editedGroupIDs)
                if state.isDetailPresented,
                   selectedGroupWasConfirmed,
                   let selectedGroupID = state.selectedGroupID,
                   let editEvent = otherMemberEdits.last(where: {
                       $0.groupID == selectedGroupID
                   }) {
                    state.detail.isGroupConfirmed = false
                    state.detail.cancellationNotice = .init(
                        memberName: editEvent.editorName,
                        character: editEvent.editor.avatar
                    )
                } else if let editEvent = otherMemberEdits.last(where: {
                    cancelledGroupIDs.contains($0.groupID)
                }) {
                    state.cancellationNotice = .init(
                        memberName: editEvent.editorName,
                        character: editEvent.editor.avatar
                    )
                }
                guard !cancelledGroupIDs.isEmpty else { return .none }
                guard let tripID = state.sourcePlaceSelection?.tripID else { return .none }
                return .run { _ in
                    for groupID in cancelledGroupIDs {
                        try? await placeClient.setGroupConfirmation(
                            tripID, groupID, false, false
                        )
                    }
                }

            case .cancellationNoticeDismissed:
                state.cancellationNotice = nil
                return .none

            case .groupMembershipsFailed,
                 .groupConfirmationsResponse,
                 .groupConfirmationsFailed:
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
                state.applyJoinedGroupMemberships()
                state.confirmedGroupIDs = []
                state.selectedGroupID = nil
                guard let tripID = state.sourcePlaceSelection?.tripID else {
                    return .merge(
                        routeGroupingEffect(for: &state),
                        .send(.delegate(.reanalyzeGrouping))
                    )
                }
                let eventID = UUID().uuidString
                state.processedGroupingConfigurationEventIDs.insert(eventID)
                return .merge(
                    routeGroupingEffect(for: &state),
                    .run { _ in
                        try? await placeClient.updateGroupingConfiguration(
                            tripID,
                            eventID,
                            selection.transportation.rawValue,
                            selection.duration.rawValue
                        )
                    },
                    .send(.delegate(.reanalyzeGrouping))
                )
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
                    currentMemberID: state.currentMemberID,
                    isGroupConfirmed: state.confirmedGroupIDs.contains(id)
                )
                state.isDetailPresented = true
                return .none
            case .detail(.delegate(.confirmed)):
                guard let selectedGroupID = state.selectedGroupID else { return .none }
                state.confirmedGroupIDs.insert(selectedGroupID)
                state.isDetailPresented = false
                guard let tripID = state.sourcePlaceSelection?.tripID else { return .none }
                return .run { _ in
                    try? await placeClient.setGroupConfirmation(
                        tripID, selectedGroupID, true, false
                    )
                }
            case .detail(.delegate(.joined)):
                guard let selectedGroupID = state.selectedGroupID else { return .none }
                state.confirmedGroupIDs.insert(selectedGroupID)
                state.joinedMemberIDsByGroupID[selectedGroupID, default: []]
                    .insert(state.currentMemberID)
                state.applyJoinedGroupMemberships()
                state.isDetailPresented = false
                guard let tripID = state.sourcePlaceSelection?.tripID else { return .none }
                return .run { send in
                    do {
                        try await placeClient.joinGroup(tripID, selectedGroupID)
                        try await placeClient.setGroupConfirmation(
                            tripID, selectedGroupID, true, false
                        )
                    } catch {
                        await send(.groupMembershipsFailed)
                    }
                }
            case let .detail(.delegate(.placeDeleted(placeID, orderedPlaceIDs))):
                guard let selectedGroupID = state.selectedGroupID else { return .none }
                state.confirmedGroupIDs.remove(selectedGroupID)
                state.deletedPlaceIDsByGroupID[selectedGroupID, default: []].insert(placeID)
                state.orderedPlaceIDsByGroupID[selectedGroupID] = orderedPlaceIDs
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
                    guard group.places.contains(where: { $0.id == placeID }) else {
                        return group
                    }
                    return MapPlaceGroup(
                        id: group.id,
                        name: group.name,
                        places: group.places.filter { $0.id != placeID },
                        radius: group.radius
                    )
                }
                guard let tripID = state.sourcePlaceSelection?.tripID else { return .none }
                return .run { send in
                    do {
                        try await placeClient.updateGroupPlaces(
                            tripID, selectedGroupID, orderedPlaceIDs, placeID
                        )
                    } catch {
                        await send(.groupMembershipsFailed)
                    }
                }
            case let .detail(.delegate(.placesReordered(orderedPlaceIDs))):
                guard let selectedGroupID = state.selectedGroupID else { return .none }
                state.confirmedGroupIDs.remove(selectedGroupID)
                state.orderedPlaceIDsByGroupID[selectedGroupID] = orderedPlaceIDs
                state.applyGroupPlaceOrders()
                guard let tripID = state.sourcePlaceSelection?.tripID else { return .none }
                return .run { send in
                    do {
                        try await placeClient.updateGroupPlaces(
                            tripID, selectedGroupID, orderedPlaceIDs, nil
                        )
                    } catch {
                        await send(.groupMembershipsFailed)
                    }
                }
            case .detail(.backButtonTapped):
                state.isDetailPresented = false
                return .none
            case .detail:
                return .none
            case .confirmButtonTapped:
                guard state.hasConfirmedRecommendedGroup else { return .none }
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
            case .selectAllRecommendedGroupsTapped:
                let groupIDs = Set(state.recommendedGroups.map(\.id))
                let shouldSelectAll = !state.haveAllRecommendedGroupsConfirmed
                if shouldSelectAll {
                    state.confirmedGroupIDs.formUnion(groupIDs)
                } else {
                    state.confirmedGroupIDs.subtract(groupIDs)
                }
                state.confirmedGroupIDsByMemberID[state.currentMemberID] = state.confirmedGroupIDs

                guard let tripID = state.sourcePlaceSelection?.tripID else { return .none }
                return .run { _ in
                    for groupID in groupIDs {
                        try? await placeClient.setGroupConfirmation(
                            tripID, groupID, shouldSelectAll, false
                        )
                    }
                }
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

    private func fetchGroupConfirmationsEffect(tripID: String) -> Effect<Action> {
        .run { send in
            do {
                await send(.groupConfirmationsResponse(
                    try await placeClient.fetchGroupConfirmations(tripID)
                ))
            } catch {
                await send(.groupConfirmationsFailed)
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

    private func observeGroupMembershipsEffect(tripID: String) -> Effect<Action> {
        let stream = placeClient.observeGroupMemberships(tripID)
        return .run { send in
            do {
                for try await memberships in stream {
                    await send(.groupMembershipsResponse(memberships))
                }
            } catch {
                await send(.groupMembershipsFailed)
            }
        }
    }

    private func placePhotoEffects(state: inout State) -> [Effect<Action>] {
        let places = state.recommendedGroups
            .flatMap(\.places)
            .reduce(into: [String: PinnedPlace]()) { result, place in
                result[place.id] = place
            }
            .values
            .filter {
                $0.photoData.isEmpty && !state.requestedPlacePhotoIDs.contains($0.id)
            }

        state.requestedPlacePhotoIDs.formUnion(places.map(\.id))
        return places.map { place in
            .run { send in
                do {
                    guard let result = try await placeClient.autocomplete(place.name).first else {
                        await send(.placePhotoResponse(place.id, nil))
                        return
                    }
                    let details = try await placeClient.fetchDetails(result)
                    await send(.placePhotoResponse(place.id, details.photoData.first))
                } catch {
                    await send(.placePhotoResponse(place.id, nil))
                }
            }
        }
    }

    private func placeIdentitySet(_ places: [PinnedPlace]) -> Set<String> {
        Set(places.map(\.id))
    }

    private func routeGroupingEffect(for state: inout State) -> Effect<Action> {
        guard let source = state.sourcePlaceSelection else { return .none }
        let places = source.participants
            .filter(\.hasJoined)
            .flatMap { source.memberPlaces[$0.member, default: []] }
        guard places.count > 1 else { return .none }
        state.isRouteGroupingLoading = true
        let transportation = state.transportationSelection.transportation
        return .run { send in
            do {
                let travelTimes = try await mapClient.fetchTravelTimes(
                    places,
                    transportation
                )
                await send(.routeTravelTimesResponse(travelTimes))
            } catch {
                await send(.routeTravelTimesFailed)
            }
        }
        .cancellable(id: "route-grouping", cancelInFlight: true)
    }
}

private extension PlaceGroupingFeature.State {
    mutating func applyGroupingResult(_ result: PlaceGroupingEngine.Result) {
        let photoDataByID = recommendedGroups
            .flatMap(\.places)
            .reduce(into: [String: [Data]]()) { values, place in
                if !place.photoData.isEmpty { values[place.id] = place.photoData }
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

        members = result.members
        placeGroups = result.mapGroups.map { group in
            MapPlaceGroup(
                id: group.id,
                name: group.name,
                places: group.places.map(enrich),
                radius: group.radius
            )
        }
        recommendedGroups = result.recommendedGroups.map { group in
            PlaceGroupingFeature.RecommendedGroup(
                id: group.id,
                title: group.title,
                participantSummary: group.participantSummary,
                memberIDs: group.memberIDs,
                categories: group.categories,
                places: group.places.map(enrich)
            )
        }
        applyJoinedGroupMemberships()
        applyDeletedGroupPlaces()
        applyGroupPlaceOrders()
        confirmedGroupIDs.formIntersection(recommendedGroups.map(\.id))
    }

    mutating func applyGroupingConfiguration(_ event: GroupingConfigurationEvent) {
        guard let transportation = Transportation(rawValue: event.transportation),
              let duration = TravelDuration(rawValue: event.durationMinutes),
              let sourcePlaceSelection
        else { return }

        let selection = TripSetUpTransportationFeature.Selection(
            transportation: transportation,
            duration: duration
        )
        transportationSelection = selection
        transportationSheet = TripSetUpTransportationFeature.State(selection: selection)
        travelCriteria = "\(transportation.title) · 장소 간 최대 \(duration.rawValue)분"

        let refreshed = PlaceGroupingEngine.makeGroups(
            from: sourcePlaceSelection,
            selection: selection
        )
        members = refreshed.members
        placeGroups = refreshed.mapGroups
        recommendedGroups = refreshed.recommendedGroups
        applyJoinedGroupMemberships()
        applyDeletedGroupPlaces()
        applyGroupPlaceOrders()
        confirmedGroupIDs = []
        selectedGroupID = nil
        isDetailPresented = false
    }

    mutating func applyJoinedGroupMemberships() {
        recommendedGroups = recommendedGroups.map { group in
            let joinedMemberIDs = joinedMemberIDsByGroupID[group.id, default: []]
            guard !joinedMemberIDs.isEmpty else { return group }

            let memberIDs = group.memberIDs + joinedMemberIDs
                .filter { !group.memberIDs.contains($0) }
                .sorted()
            return PlaceGroupingFeature.RecommendedGroup(
                id: group.id,
                title: group.title,
                participantSummary: "\(memberIDs.count)명",
                memberIDs: memberIDs,
                categories: group.categories,
                places: group.places
            )
        }
    }

    mutating func applyDeletedGroupPlaces() {
        recommendedGroups = recommendedGroups.map { group in
            let deletedPlaceIDs = deletedPlaceIDsByGroupID[group.id, default: []]
            guard !deletedPlaceIDs.isEmpty else { return group }
            return PlaceGroupingFeature.RecommendedGroup(
                id: group.id,
                title: group.title,
                participantSummary: group.participantSummary,
                memberIDs: group.memberIDs,
                categories: group.categories,
                places: group.places.filter { !deletedPlaceIDs.contains($0.id) }
            )
        }
        let allDeletedPlaceIDs = deletedPlaceIDsByGroupID.values.reduce(into: Set<String>()) {
            $0.formUnion($1)
        }
        placeGroups = placeGroups.map { group in
            guard !allDeletedPlaceIDs.isEmpty else { return group }
            return MapPlaceGroup(
                id: group.id,
                name: group.name,
                places: group.places.filter { !allDeletedPlaceIDs.contains($0.id) },
                radius: group.radius
            )
        }
        if let selectedGroupID,
           let deletedPlaceIDs = deletedPlaceIDsByGroupID[selectedGroupID],
           !deletedPlaceIDs.isEmpty {
            detail.places.removeAll { deletedPlaceIDs.contains($0.id) }
        }
    }

    mutating func applyGroupPlaceOrders() {
        func ordered(_ places: [PinnedPlace], ids: [String]) -> [PinnedPlace] {
            let indexByID = Dictionary(uniqueKeysWithValues: ids.enumerated().map {
                ($0.element, $0.offset)
            })
            return places.sorted {
                indexByID[$0.id, default: Int.max] < indexByID[$1.id, default: Int.max]
            }
        }

        recommendedGroups = recommendedGroups.map { group in
            guard let ids = orderedPlaceIDsByGroupID[group.id] else { return group }
            return PlaceGroupingFeature.RecommendedGroup(
                id: group.id,
                title: group.title,
                participantSummary: group.participantSummary,
                memberIDs: group.memberIDs,
                categories: group.categories,
                places: ordered(group.places, ids: ids)
            )
        }
        placeGroups = placeGroups.map { group in
            guard let ids = orderedPlaceIDsByGroupID[group.id] else { return group }
            return MapPlaceGroup(
                id: group.id,
                name: group.name,
                places: ordered(group.places, ids: ids),
                radius: group.radius
            )
        }
        if let selectedGroupID,
           let ids = orderedPlaceIDsByGroupID[selectedGroupID] {
            let indexByID = Dictionary(uniqueKeysWithValues: ids.enumerated().map {
                ($0.element, $0.offset)
            })
            detail.places.sort {
                indexByID[$0.id, default: Int.max] < indexByID[$1.id, default: Int.max]
            }
        }
    }
}

private enum PlaceGroupingEngine {
    private static let maximumPlacesPerCourse = 5

    struct Result {
        let members: [PlaceGroupingFeature.Member]
        let mapGroups: [MapPlaceGroup]
        let recommendedGroups: [PlaceGroupingFeature.RecommendedGroup]
    }

    private struct OwnedPlace {
        var members: Set<TripMember>
        let place: PinnedPlace
    }

    static func makeGroups(
        from state: PlaceSelectionFeature.State,
        selection: TripSetUpTransportationFeature.Selection,
        travelTimes: RouteTravelTimeMatrix? = nil
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

        let selectedPlaces = joined.flatMap { participant in
            state.memberPlaces[participant.member, default: []].map {
                OwnedPlace(members: [participant.member], place: $0)
            }
        }
        let ownedPlaces = mergingSamePlaces(selectedPlaces)
        let regions = completeLinkRegions(
            ownedPlaces,
            maximumDistance: maximumDistance(for: selection),
            maximumTravelTime: TimeInterval(selection.duration.rawValue * 60),
            travelTimes: travelTimes
        )
        let mapGroups = regions.enumerated().map { index, region in
            let places = unique(region.map(\.place))
            return MapPlaceGroup(
                id: "region-\(index)",
                name: courseName(
                    places: places,
                    destination: state.destinationName,
                    index: index
                ),
                places: places,
                radius: enclosingRadius(of: region)
            )
        }
        var recommendations: [PlaceGroupingFeature.RecommendedGroup] = []
        for (regionIndex, region) in regions.enumerated() {
            let preferences = memberPreferences(in: region)
            let courses = recommendedCourses(
                in: region,
                preferences: preferences,
                maximumDistance: maximumDistance(for: selection),
                maximumTravelTime: TimeInterval(selection.duration.rawValue * 60),
                travelTimes: travelTimes
            )
            for (courseIndex, course) in courses.enumerated() {
                let places = course.map(\.place)
                let memberIDs = Array(Set(
                    course.flatMap(\.members).map(\.rawValue)
                )).sorted()
                let categories = Array(Set(
                    places.map { normalizedCategory($0.category) }
                )).sorted()
                let regionName = mapGroups[regionIndex].name
                recommendations.append(
                    PlaceGroupingFeature.RecommendedGroup(
                        id: "region-\(regionIndex)-course-\(courseIndex)",
                        title: courses.count == 1
                            ? regionName
                            : "\(regionName) \(courseIndex + 1)",
                        participantSummary: "\(memberIDs.count)명",
                        memberIDs: memberIDs,
                        categories: categories,
                        places: places
                    )
                )
            }
        }

        return Result(
            members: members,
            mapGroups: mapGroups,
            recommendedGroups: recommendations
        )
    }

    /// 어느 한 장소만 이어지는 단순 연결 그룹이 아니라,
    /// 합친 지역 안의 모든 장소 쌍이 이동시간 조건을 만족할 때만 합친다.
    private static func completeLinkRegions(
        _ places: [OwnedPlace],
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> [[OwnedPlace]] {
        var regions = places.map { [$0] }
        while true {
            var bestPair: (lhs: Int, rhs: Int, distance: Double)?
            guard regions.count > 1 else { break }
            for lhs in regions.indices {
                for rhs in regions.indices where rhs > lhs {
                    guard canMergeRegions(
                        regions[lhs],
                        regions[rhs],
                        maximumDistance: maximumDistance,
                        maximumTravelTime: maximumTravelTime,
                        travelTimes: travelTimes
                    ) else { continue }
                    let candidateDistance = distanceBetweenRegions(regions[lhs], regions[rhs])
                    if bestPair == nil || candidateDistance < bestPair!.distance {
                        bestPair = (lhs, rhs, candidateDistance)
                    }
                }
            }
            guard let pair = bestPair else { break }
            regions[pair.lhs].append(contentsOf: regions[pair.rhs])
            regions.remove(at: pair.rhs)
        }
        return regions
    }

    private static func canMergeRegions(
        _ lhs: [OwnedPlace],
        _ rhs: [OwnedPlace],
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> Bool {
        lhs.allSatisfy { left in
            rhs.allSatisfy { right in
                areWithinTravelLimit(
                    left.place,
                    right.place,
                    maximumDistance: maximumDistance,
                    maximumTravelTime: maximumTravelTime,
                    travelTimes: travelTimes
                )
            }
        }
    }

    /// 해당 지역에서 멤버가 선택한 장소의 카테고리 비율을 계산한다.
    private static func memberPreferences(
        in region: [OwnedPlace]
    ) -> [TripMember: [String: Double]] {
        var counts: [TripMember: [String: Int]] = [:]
        for ownedPlace in region {
            let category = normalizedCategory(ownedPlace.place.category)
            for member in ownedPlace.members {
                counts[member, default: [:]][category, default: 0] += 1
            }
        }
        return counts.mapValues { categoryCounts in
            let total = Double(categoryCounts.values.reduce(0, +))
            guard total > 0 else { return [:] }
            return categoryCounts.mapValues { Double($0) / total }
        }
    }

    /// 최소 코스 수로 시작하고, 코스를 하나 늘린 안의
    /// 취향·선택 장소 비율·이동시간 점수가 더 높을 때만 분리한다.
    private static func recommendedCourses(
        in region: [OwnedPlace],
        preferences: [TripMember: [String: Double]],
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> [[OwnedPlace]] {
        guard !region.isEmpty else { return [] }
        let minimumCount = Int(ceil(
            Double(region.count) / Double(maximumPlacesPerCourse)
        ))
        var best = makeCourses(
            from: region,
            count: minimumCount,
            preferences: preferences,
            maximumDistance: maximumDistance,
            maximumTravelTime: maximumTravelTime,
            travelTimes: travelTimes
        )
        var bestScore = coursePlanScore(
            best,
            preferences: preferences,
            minimumCourseCount: minimumCount,
            maximumDistance: maximumDistance,
            maximumTravelTime: maximumTravelTime,
            travelTimes: travelTimes
        )

        guard minimumCount < region.count else { return best }
        for count in (minimumCount + 1)...region.count {
            let candidate = makeCourses(
                from: region,
                count: count,
                preferences: preferences,
                maximumDistance: maximumDistance,
                maximumTravelTime: maximumTravelTime,
                travelTimes: travelTimes
            )
            let candidateScore = coursePlanScore(
                candidate,
                preferences: preferences,
                minimumCourseCount: minimumCount,
                maximumDistance: maximumDistance,
                maximumTravelTime: maximumTravelTime,
                travelTimes: travelTimes
            )
            guard candidateScore > bestScore else { break }
            best = candidate
            bestScore = candidateScore
        }
        guard isValidCoursePlan(best, source: region) else {
            return stride(from: 0, to: region.count, by: maximumPlacesPerCourse).map {
                Array(region[$0..<min($0 + maximumPlacesPerCourse, region.count)])
            }
        }
        return best
    }

    private static func isValidCoursePlan(
        _ courses: [[OwnedPlace]],
        source: [OwnedPlace]
    ) -> Bool {
        let assignedIDs = courses.flatMap { $0.map(\.place.id) }
        return courses.allSatisfy { !$0.isEmpty && $0.count <= maximumPlacesPerCourse }
            && assignedIDs.count == source.count
            && Set(assignedIDs) == Set(source.map(\.place.id))
    }

    private static func makeCourses(
        from places: [OwnedPlace],
        count: Int,
        preferences: [TripMember: [String: Double]],
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> [[OwnedPlace]] {
        let sorted = places.sorted {
            if $0.members.count != $1.members.count {
                return $0.members.count > $1.members.count
            }
            return $0.place.id < $1.place.id
        }
        var seeds: [OwnedPlace] = [sorted[0]]
        var remaining = Array(sorted.dropFirst())
        while seeds.count < count, !remaining.isEmpty {
            let index = remaining.indices.max { lhs, rhs in
                seedSeparation(
                    remaining[lhs],
                    from: seeds,
                    maximumDistance: maximumDistance,
                    maximumTravelTime: maximumTravelTime,
                    travelTimes: travelTimes
                ) < seedSeparation(
                    remaining[rhs],
                    from: seeds,
                    maximumDistance: maximumDistance,
                    maximumTravelTime: maximumTravelTime,
                    travelTimes: travelTimes
                )
            }!
            seeds.append(remaining.remove(at: index))
        }

        var courses = seeds.map { [$0] }
        remaining.sort {
            if $0.members.count != $1.members.count {
                return $0.members.count > $1.members.count
            }
            return $0.place.id < $1.place.id
        }
        for place in remaining {
            let candidates = courses.indices.filter {
                courses[$0].count < maximumPlacesPerCourse
            }
            guard let bestIndex = candidates.max(by: { lhs, rhs in
                placementScore(
                    place,
                    in: courses[lhs],
                    preferences: preferences,
                    maximumDistance: maximumDistance,
                    maximumTravelTime: maximumTravelTime,
                    travelTimes: travelTimes
                ) < placementScore(
                    place,
                    in: courses[rhs],
                    preferences: preferences,
                    maximumDistance: maximumDistance,
                    maximumTravelTime: maximumTravelTime,
                    travelTimes: travelTimes
                )
            }) else { continue }
            courses[bestIndex].append(place)
        }
        return courses
    }

    private static func placementScore(
        _ candidate: OwnedPlace,
        in course: [OwnedPlace],
        preferences: [TripMember: [String: Double]],
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> Double {
        let courseMembers = Set(course.flatMap(\.members))
        let sharedMemberScore = Double(candidate.members.intersection(courseMembers).count)
            / Double(max(candidate.members.union(courseMembers).count, 1))
        let category = normalizedCategory(candidate.place.category)
        let candidatePreference = candidate.members.map {
            preferences[$0]?[category] ?? 0
        }.average
        let coursePreference = courseMembers.map {
            preferences[$0]?[category] ?? 0
        }.average
        let preferenceScore = (candidatePreference + coursePreference) / 2
        let travelScore = course.map {
            proximityScore(
                candidate.place,
                $0.place,
                maximumDistance: maximumDistance,
                maximumTravelTime: maximumTravelTime,
                travelTimes: travelTimes
            )
        }.average
        // 멤버 겹침 > 취향 유사도 > 이동시간 순서가 뒤집히지 않도록
        // 각 단계의 가중치 범위를 분리한다.
        return sharedMemberScore * 100 + preferenceScore * 10 + travelScore
    }

    private static func seedSeparation(
        _ candidate: OwnedPlace,
        from seeds: [OwnedPlace],
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> Double {
        seeds.map { seed in
            let memberSimilarity = Double(candidate.members.intersection(seed.members).count)
                / Double(max(candidate.members.union(seed.members).count, 1))
            let proximity = proximityScore(
                candidate.place,
                seed.place,
                maximumDistance: maximumDistance,
                maximumTravelTime: maximumTravelTime,
                travelTimes: travelTimes
            )
            return (1 - memberSimilarity) * 0.6 + (1 - proximity) * 0.4
        }.min() ?? 0
    }

    private static func coursePlanScore(
        _ courses: [[OwnedPlace]],
        preferences: [TripMember: [String: Double]],
        minimumCourseCount: Int,
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> Double {
        let members = Set(courses.flatMap { $0.flatMap(\.members) })
        let memberFit = members.map { member in
            let participating = courses.filter { course in
                course.contains { $0.members.contains(member) }
            }
            return participating.map { course in
                let ownPlaceRatio = Double(course.count { $0.members.contains(member) })
                    / Double(max(course.count, 1))
                let interestRatio = course.map {
                    preferences[member]?[normalizedCategory($0.place.category)] ?? 0
                }.average
                return ownPlaceRatio * 0.7 + interestRatio * 0.3
            }.average
        }.average

        let travelFit = courses.map { course in
            guard course.count > 1 else { return 1.0 }
            var scores: [Double] = []
            for lhs in course.indices {
                for rhs in course.indices where rhs > lhs {
                    scores.append(
                        proximityScore(
                            course[lhs].place,
                            course[rhs].place,
                            maximumDistance: maximumDistance,
                            maximumTravelTime: maximumTravelTime,
                            travelTimes: travelTimes
                        )
                    )
                }
            }
            return scores.average
        }.average
        let additionalCoursePenalty = Double(max(courses.count - minimumCourseCount, 0)) * 0.1
        return memberFit * 0.7 + travelFit * 0.3 - additionalCoursePenalty
    }

    private static func proximityScore(
        _ lhs: PinnedPlace,
        _ rhs: PinnedPlace,
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> Double {
        if let duration = travelDuration(lhs, rhs, travelTimes: travelTimes) {
            return max(0, 1 - duration / max(maximumTravelTime, 1))
        }
        return max(0, 1 - distance(lhs, rhs) / max(maximumDistance, 1))
    }

    private static func areWithinTravelLimit(
        _ lhs: PinnedPlace,
        _ rhs: PinnedPlace,
        maximumDistance: Double,
        maximumTravelTime: TimeInterval,
        travelTimes: RouteTravelTimeMatrix?
    ) -> Bool {
        if let duration = travelDuration(lhs, rhs, travelTimes: travelTimes) {
            return duration <= maximumTravelTime
        }
        return distance(lhs, rhs) <= maximumDistance
    }

    private static func travelDuration(
        _ lhs: PinnedPlace,
        _ rhs: PinnedPlace,
        travelTimes: RouteTravelTimeMatrix?
    ) -> TimeInterval? {
        guard let travelTimes else { return nil }
        return [
            travelTimes.duration(from: lhs.id, to: rhs.id),
            travelTimes.duration(from: rhs.id, to: lhs.id)
        ]
        .compactMap { $0 }
        .min()
    }

    /// 같은 Google Place를 여러 명이 선택해도 장소 하나와 하나의 추천 그룹으로 취급한다.
    /// 선택한 사람들은 대표 장소의 `members`에 합쳐 추천 그룹 참여자로 표시한다.
    private static func mergingSamePlaces(_ places: [OwnedPlace]) -> [OwnedPlace] {
        places.reduce(into: [OwnedPlace]()) { result, ownedPlace in
            guard let index = result.firstIndex(where: {
                isSamePlace($0.place, ownedPlace.place)
            }) else {
                result.append(ownedPlace)
                return
            }
            result[index].members.formUnion(ownedPlace.members)
        }
    }

    private static func maximumDistance(
        for selection: TripSetUpTransportationFeature.Selection
    ) -> Double {
        let metersPerMinute: Double = selection.transportation == .publicTransit ? 183 : 500
        return Double(selection.duration.rawValue) * metersPerMinute
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

    private static func isSamePlace(_ lhs: PinnedPlace, _ rhs: PinnedPlace) -> Bool {
        lhs.id == rhs.id
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

    private static func enclosingRadius(of region: [OwnedPlace]) -> Double {
        max(350, regionRadius(unique(region.map(\.place))) + 200)
    }

    private static func distanceBetweenRegions(
        _ lhs: [OwnedPlace],
        _ rhs: [OwnedPlace]
    ) -> Double {
        regionCenter(lhs).distance(from: regionCenter(rhs))
    }

    private static func regionCenter(_ region: [OwnedPlace]) -> CLLocation {
        // 여러 명이 같은 장소를 선택해도 중심점이 특정 장소 쪽으로
        // 치우치 않도록 지도에 표시하는 고유 장소를 기준으로 계산한다.
        let places = unique(region.map(\.place))
        let count = Double(max(places.count, 1))
        return CLLocation(
            latitude: places.map(\.latitude).reduce(0, +) / count,
            longitude: places.map(\.longitude).reduce(0, +) / count
        )
    }

    private static func unique(_ places: [PinnedPlace]) -> [PinnedPlace] {
        places.reduce(into: [PinnedPlace]()) { result, place in
            guard !result.contains(where: { isSamePlace($0, place) }) else { return }
            result.append(place)
        }
    }

    private static func courseName(
        places: [PinnedPlace],
        destination: String,
        index: Int
    ) -> String {
        guard let representativePlace = places.first else {
            return "\(destination) 코스 \(index + 1)"
        }
        if places.count == 1 {
            return "\(representativePlace.name) 코스"
        }
        return "\(representativePlace.name) 중심 코스"
    }
}

private extension Collection where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
