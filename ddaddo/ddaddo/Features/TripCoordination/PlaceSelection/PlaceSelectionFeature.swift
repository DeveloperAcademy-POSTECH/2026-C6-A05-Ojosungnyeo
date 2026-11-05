//
//  PlaceSelectionFeature.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture
import CoreGraphics
import Foundation

struct PlaceSelectionFeature: Reducer {
    enum Delegate: Equatable {
        case proceedToAnalysis
        case returnToInvitation
    }

    enum CompletionAlert: Equatable {
        case allMembersConfirmed
        case selectionTimeExpired

        var title: String {
            switch self {
            case .allMembersConfirmed:
                "모두 장소 선택을 마쳤어요"
            case .selectionTimeExpired:
                "72시간이 지났어요"
            }
        }

    }

    struct Participant: Equatable, Identifiable, Sendable {
        let id: Int
        let member: TripMember
        let name: String
        var hasJoined: Bool
        let isCurrentUser: Bool
        var isConfirmed: Bool

        init(
            id: Int,
            member: TripMember,
            name: String,
            hasJoined: Bool,
            isCurrentUser: Bool,
            isConfirmed: Bool = false
        ) {
            self.id = id
            self.member = member
            self.name = name
            self.hasJoined = hasJoined
            self.isCurrentUser = isCurrentUser
            self.isConfirmed = isConfirmed
        }
    }

    @ObservableState
    struct State: Equatable {
        var tripID: String
        var tripTitle: String
        var destinationName: String
        var tripStartDate: Date
        var tripEndDate: Date
        var participants: [Participant]
        var searchText = ""
        var isBottomSheetExpanded = true
        var isMemberPlacesSheetPresented = false
        var isSearchPresented = false
        var selectedPlace: PlaceDetails?
        var selectedPinnedPlace: PinnedPlace?
        var isPlaceDetailsLoading = false
        var selectedMember: TripMember
        var memberPlaces: [TripMember: [PinnedPlace]]
        var remainingSeconds: Int
        var isTimerRunning = false
        var hasSelectionEnded = false
        var isEditingConfirmedPlaces = false
        var completionAlert: CompletionAlert?
        var placeSyncErrorMessage: String?
        var requestedPhotoPlaceIDs: Set<String> = []
        var hasRestoredSavedPlacesPresentation = false
        var placeSearch = PlaceSearchFeature.State()

        init(
            tripID: String = "preview-trip",
            tripTitle: String = "도쿄 여행",
            destinationName: String = "도쿄",
            tripStartDate: Date = Date(),
            tripEndDate: Date? = nil,
            participants: [Participant] = Self.mockParticipants,
            memberPlaces: [TripMember: [PinnedPlace]] = [:],
            remainingSeconds: Int = 72 * 60 * 60
        ) {
            let resolvedEndDate = tripEndDate
                ?? Calendar.current.date(byAdding: .day, value: 3, to: tripStartDate)!
            let selectedMember = participants.first(where: \.isCurrentUser)?.member
                ?? participants.first(where: \.hasJoined)?.member
                ?? .tae

            self.tripID = tripID
            self.tripTitle = tripTitle
            self.destinationName = destinationName
            self.tripStartDate = tripStartDate
            self.tripEndDate = resolvedEndDate
            self.participants = participants
            self.selectedMember = selectedMember
            self.memberPlaces = memberPlaces
            self.remainingSeconds = remainingSeconds
        }

        var numberOfNights: Int {
            let calendar = Calendar(identifier: .gregorian)
            let start = calendar.startOfDay(for: tripStartDate)
            let end = calendar.startOfDay(for: tripEndDate)
            return max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 1)
        }

        var maximumPlaceCount: Int {
            numberOfDays * 2
        }

        var numberOfDays: Int {
            numberOfNights + 1
        }

        var navigationTitle: String {
            "\(numberOfNights)박 \(numberOfDays)일 \(destinationName) 여행"
        }

        var currentMember: TripMember {
            participants.first(where: \.isCurrentUser)?.member ?? selectedMember
        }

        var selectedPlaceCount: Int {
            memberPlaces[selectedMember]?.count ?? 0
        }

        var isViewingCurrentUser: Bool {
            selectedMember == currentMember
        }

        var canEditDisplayedPlaces: Bool {
            isViewingCurrentUser && !isCurrentUserConfirmed && !hasSelectionEnded
        }

        var canConfirmPlaceSelection: Bool {
            !memberPlaces[currentMember, default: []].isEmpty
                && !isCurrentUserConfirmed
                && !hasSelectionEnded
        }

        var isCurrentUserConfirmed: Bool {
            participants.first(where: \.isCurrentUser)?.isConfirmed == true
        }

        var haveAllParticipantsJoinedAndConfirmed: Bool {
            !participants.isEmpty
                && participants.allSatisfy { $0.hasJoined && $0.isConfirmed }
        }

        var completionAlertMessage: String {
            switch completionAlert {
            case .allMembersConfirmed:
                return "\(participants.count)명 모두 장소핀을 확정했어요.\n이제 함께 갈 장소를 묶어볼까요?"
            case .selectionTimeExpired:
                return "지금까지 확정된 장소핀으로\n다음 그룹핑 단계를 시작해 볼까요?"
            case nil:
                return ""
            }
        }

        var isShowingConfirmedPlaces: Bool {
            isCurrentUserConfirmed || hasSelectionEnded
        }

        var confirmedPlaces: [PinnedPlace] {
            var placeIDs = Set<String>()

            return participants
                .filter { $0.hasJoined && $0.isConfirmed }
                .flatMap { memberPlaces[$0.member, default: []] }
                .filter { placeIDs.insert($0.id).inserted }
        }

        /// 확정 화면의 지도에는 확정 여부와 관계없이 참여 중인 멤버가 찍은 핀을 모두 보여 준다.
        /// 따라서 방 관리자(또는 다른 참여자)가 먼저 선택한 장소도 UFO로 함께 표시된다.
        var joinedMemberPlaces: [PinnedPlace] {
            var placeIDs = Set<String>()

            return participants
                .filter(\.hasJoined)
                .flatMap { memberPlaces[$0.member, default: []] }
                .filter { placeIDs.insert($0.id).inserted }
        }

        var mapPlaces: [PinnedPlace] {
            isShowingConfirmedPlaces ? joinedMemberPlaces : displayedPlaces
        }

        var isSelectedPlaceAlreadyAdded: Bool {
            if selectedPinnedPlace != nil { return true }
            guard let selectedPlace else { return false }
            return memberPlaces[currentMember, default: []].contains {
                $0.id == selectedPlace.id
            }
        }

        var canAddSelectedPlace: Bool {
            selectedPlace != nil
                && isViewingCurrentUser
                && !isSelectedPlaceAlreadyAdded
                && memberPlaces[currentMember, default: []].count < maximumPlaceCount
        }

        var currentParticipant: Participant? {
            participants.first(where: { $0.member == selectedMember })
        }

        var displayedPlaces: [PinnedPlace] {
            guard currentParticipant?.hasJoined != false else { return [] }
            return memberPlaces[selectedMember] ?? []
        }

        mutating func updateTripContext(
            tripID: String,
            tripTitle: String,
            destinationName: String,
            tripStartDate: Date,
            tripEndDate: Date,
            participants: [Participant],
            remainingSeconds: Int
        ) {
            self.tripID = tripID
            self.tripTitle = tripTitle
            self.destinationName = destinationName
            self.tripStartDate = tripStartDate
            self.tripEndDate = tripEndDate
            self.participants = participants
            self.remainingSeconds = remainingSeconds

            let selectableMembers = participants.filter(\.hasJoined).map(\.member)
            if !selectableMembers.contains(selectedMember) {
                selectedMember = participants.first(where: \.isCurrentUser)?.member
                    ?? selectableMembers.first
                    ?? .tae
            }
        }

        var timerText: String {
            let hours = remainingSeconds / 3_600
            let minutes = remainingSeconds % 3_600 / 60
            let seconds = remainingSeconds % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        private static let mockParticipants: [Participant] = [
            .init(id: 0, member: .tae, name: "테이", hasJoined: true, isCurrentUser: true),
            .init(id: 1, member: .header, name: "헤더", hasJoined: true, isCurrentUser: false),
            .init(id: 2, member: .grae, name: "그레", hasJoined: true, isCurrentUser: false),
            .init(id: 3, member: .juni, name: "주니", hasJoined: false, isCurrentUser: false)
        ]

        static let mockMemberPlaces: [TripMember: [PinnedPlace]] = [
            .tae: [
                PinnedPlace(
                    id: "tae-restaurant",
                    name: "임연수 랜드",
                    description: "이 장소는 어쩌구 저쩌구에서 가장 유명한 맛집입니다. 임연수 구이가 가장 맛있습니다.",
                    thumbnailName: "DDMockPlaceRestaurant",
                    category: "맛집",
                    latitude: 35.6696,
                    longitude: 139.7051
                ),
                PinnedPlace(
                    id: "tae-frappe",
                    name: "도쿄 말차 프라페",
                    description: "한 번만 먹어본 사람은 없는 말차 프라페 맛집입니다. 바나나를 추가할 경우 100엔 추가됩니다.",
                    thumbnailName: "DDMockPlaceFrappe",
                    category: "디저트",
                    latitude: 35.6654,
                    longitude: 139.7101
                ),
                PinnedPlace(
                    id: "tae-village",
                    name: "스머프 빌리지",
                    description: "진짜 스머프가 살았던 곳입니다. 버섯 스프를 만들어 먹을 수 있습니다.",
                    thumbnailName: "",
                    category: "관광지",
                    latitude: 35.6619,
                    longitude: 139.7004
                )
            ],
            .header: [
                PinnedPlace(
                    id: "header-frappe",
                    name: "시부야 말차 연구소",
                    description: "진한 말차와 우유를 함께 즐길 수 있는 작은 카페입니다.",
                    thumbnailName: "DDMockPlaceFrappe",
                    category: "카페",
                    latitude: 35.6595,
                    longitude: 139.7005
                ),
                PinnedPlace(
                    id: "header-village",
                    name: "도쿄 골목 산책",
                    description: "조용한 골목과 작은 상점이 이어지는 산책 코스입니다.",
                    thumbnailName: "",
                    category: "쇼핑",
                    latitude: 35.6727,
                    longitude: 139.7038
                )
            ],
            .grae: [
                PinnedPlace(
                    id: "grae-restaurant",
                    name: "오모테산도 키친",
                    description: "현지 식재료로 만든 메뉴를 맛볼 수 있는 레스토랑입니다.",
                    thumbnailName: "DDMockPlaceRestaurant",
                    category: "맛집",
                    latitude: 35.6673,
                    longitude: 139.7130
                ),
                PinnedPlace(
                    id: "grae-village",
                    name: "하라주쿠 스트리트",
                    description: "개성 있는 숍과 전시 공간이 모여 있는 거리입니다.",
                    thumbnailName: "",
                    category: "관광지",
                    latitude: 35.6702,
                    longitude: 139.7026
                )
            ],
            .juni: [
                PinnedPlace(
                    id: "juni-frappe",
                    name: "유자 프라페 하우스",
                    description: "상큼한 유자와 말차 음료가 인기인 디저트 카페입니다.",
                    thumbnailName: "DDMockPlaceFrappe",
                    category: "디저트",
                    latitude: 35.6643,
                    longitude: 139.7067
                )
            ]
        ]
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case onDisappear
        case refreshMemberPlaces
        case memberPlacesResponse([MemberPlacePins])
        case memberPlacesFailed
        case placePhotoResponse(String, [Data])
        case placeMutationFailed(String)
        case placeSyncErrorDismissed
        case backButtonTapped
        case searchFieldTapped
        case searchTextChanged(String)
        case searchButtonTapped
        case dimmedBackgroundTapped
        case bottomSheetDragEnded(CGFloat)
        case searchFieldClearButtonTapped
        case selectedPlaceCloseButtonTapped
        case addSelectedPlaceButtonTapped
        case pinnedPlaceTapped(PinnedPlace)
        case pinnedPlaceDetailsResponse(String, PlaceDetails)
        case pinnedPlaceDetailsFailed(String)
        case deletePinnedPlaceButtonTapped(String)
        case movePinnedPlace(sourceID: String, beforeID: String?)
        case memberProfileTapped(TripMember)
        case confirmButtonTapped
        case confirmedPlacesEditButtonTapped
        case deleteConfirmedPlaceButtonTapped(String)
        case completionAlertConfirmButtonTapped
        case timerTicked
        case moveCriteriaButtonTapped
        case placeDetailsResponse(PlaceDetails)
        case placeDetailsFailed
        case searchDismissed
        case placeSearch(PlaceSearchFeature.Action)
        case delegate(Delegate)
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.remainingSeconds <= 0 {
                    state.isTimerRunning = false
                    state.hasSelectionEnded = true
                    state.isBottomSheetExpanded = true
                    state.isSearchPresented = false
                    state.completionAlert = .selectionTimeExpired
                    return loadMemberPlacesEffect(tripID: state.tripID)
                }

                let tripID = state.tripID
                var effects: [Effect<Action>] = [
                    loadMemberPlacesEffect(tripID: tripID),
                    observeMemberPlacesEffect(tripID: tripID)
                    .cancellable(id: "place-selection-sync", cancelInFlight: true)
                ]
                if !state.isTimerRunning && !state.hasSelectionEnded {
                    state.isTimerRunning = true
                    effects.append(
                        .run { send in
                            while !Task.isCancelled {
                                try await clock.sleep(for: .seconds(1))
                                await send(.timerTicked)
                            }
                        }
                        .cancellable(id: "place-selection-timer", cancelInFlight: true)
                    )
                }
                return .merge(effects)

            case .onDisappear:
                state.isTimerRunning = false
                return .merge(
                    .cancel(id: "place-selection-timer"),
                    .cancel(id: "place-selection-sync")
                )

            case .refreshMemberPlaces:
                return loadMemberPlacesEffect(tripID: state.tripID)

            case let .memberPlacesResponse(memberPins):
                let cachedPhotoData = state.memberPlaces
                    .values
                    .flatMap { $0 }
                    .reduce(into: [String: [Data]]()) { result, place in
                        if !place.photoData.isEmpty {
                            result[place.id] = place.photoData
                        }
                    }
                var photoEffects: [Effect<Action>] = []
                let joinedMembers = Set(memberPins.map(\.member))

                for index in state.participants.indices {
                    state.participants[index].hasJoined = joinedMembers.contains(
                        state.participants[index].member
                    )
                }

                for pins in memberPins {
                    state.memberPlaces[pins.member] = pins.places.map { place in
                        guard place.photoData.isEmpty,
                              let photoData = cachedPhotoData[place.id]
                        else { return place }
                        return placeWithPhotoData(place, photoData: photoData)
                    }
                    if let index = state.participants.firstIndex(where: {
                        $0.member == pins.member
                    }) {
                        state.participants[index].isConfirmed =
                            state.participants[index].isConfirmed || pins.isConfirmed
                    }
                }

                if !state.hasRestoredSavedPlacesPresentation,
                   !state.memberPlaces[state.currentMember, default: []].isEmpty,
                   state.selectedPlace == nil,
                   !state.isSearchPresented {
                    state.hasRestoredSavedPlacesPresentation = true
                    state.selectedMember = state.currentMember
                    state.isMemberPlacesSheetPresented = true
                    state.isBottomSheetExpanded = true
                }

                let placesNeedingPhotos = state.memberPlaces
                    .values
                    .flatMap { $0 }
                    .reduce(into: [String: PinnedPlace]()) { result, place in
                        guard place.photoData.isEmpty,
                              !state.requestedPhotoPlaceIDs.contains(place.id)
                        else { return }
                        result[place.id] = place
                    }
                state.requestedPhotoPlaceIDs.formUnion(placesNeedingPhotos.keys)
                photoEffects = placesNeedingPhotos.values.map(loadPlacePhotoEffect)

                if state.isCurrentUserConfirmed,
                   state.haveAllParticipantsJoinedAndConfirmed,
                   !state.hasSelectionEnded,
                   state.completionAlert == nil {
                    state.isTimerRunning = false
                    state.hasSelectionEnded = true
                    state.completionAlert = .allMembersConfirmed
                    return .merge(
                        .merge(photoEffects),
                        .cancel(id: "place-selection-timer"),
                        .cancel(id: "place-selection-sync")
                    )
                }
                return photoEffects.isEmpty ? .none : .merge(photoEffects)

            case .memberPlacesFailed:
                return .none

            case let .placePhotoResponse(placeID, photoData):
                guard !photoData.isEmpty else { return .none }
                for member in state.memberPlaces.keys {
                    state.memberPlaces[member] = state.memberPlaces[member, default: []]
                        .map { place in
                            guard place.id == placeID else { return place }
                            return placeWithPhotoData(place, photoData: photoData)
                        }
                }
                if let selectedPinnedPlace = state.selectedPinnedPlace,
                   selectedPinnedPlace.id == placeID {
                    state.selectedPinnedPlace = placeWithPhotoData(
                        selectedPinnedPlace,
                        photoData: photoData
                    )
                }
                return .none

            case let .placeMutationFailed(message):
                state.placeSyncErrorMessage = message
                return loadMemberPlacesEffect(tripID: state.tripID)

            case .placeSyncErrorDismissed:
                state.placeSyncErrorMessage = nil
                return .none

            case .backButtonTapped:
                return .send(.delegate(.returnToInvitation))

            case .searchFieldTapped:
                state.selectedMember = state.currentMember
                let shouldResetSearch = state.selectedPlace == nil
                if shouldResetSearch {
                    state.placeSearch = PlaceSearchFeature.State()
                    state.isMemberPlacesSheetPresented = true
                }
                state.isSearchPresented = true
                return shouldResetSearch
                    ? .cancel(id: "place-search")
                    : .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case .searchButtonTapped:
                state.selectedMember = state.currentMember
                state.selectedPinnedPlace = nil
                state.placeSearch = PlaceSearchFeature.State()
                state.isMemberPlacesSheetPresented = true
                state.isBottomSheetExpanded = false
                state.isSearchPresented = true
                return .cancel(id: "place-search")

            case .dimmedBackgroundTapped:
                state.isBottomSheetExpanded = false
                return .none

            case let .bottomSheetDragEnded(translation):
                guard state.selectedPlace == nil else { return .none }
                if translation > 40 {
                    state.isBottomSheetExpanded = false
                } else if translation < -40 {
                    state.isBottomSheetExpanded = true
                }
                return .none

            case .searchFieldClearButtonTapped:
                state.searchText = ""
                state.placeSearch = PlaceSearchFeature.State()
                state.selectedPlace = nil
                state.selectedPinnedPlace = nil
                state.isPlaceDetailsLoading = false
                state.isMemberPlacesSheetPresented = true
                state.isBottomSheetExpanded = true
                return .cancel(id: "place-search")

            case .selectedPlaceCloseButtonTapped:
                state.searchText = ""
                state.placeSearch = PlaceSearchFeature.State()
                state.selectedPlace = nil
                state.selectedPinnedPlace = nil
                state.isPlaceDetailsLoading = false
                state.isMemberPlacesSheetPresented = true
                state.isBottomSheetExpanded = true
                return .cancel(id: "place-search")

            case .addSelectedPlaceButtonTapped:
                guard
                    state.canAddSelectedPlace,
                    let selectedPlace = state.selectedPlace
                else { return .none }

                let pinnedPlace = PinnedPlace(
                        id: selectedPlace.id,
                        name: selectedPlace.name,
                        description: selectedPlace.address,
                        thumbnailName: "",
                        category: selectedPlace.category,
                        photoData: selectedPlace.photoData,
                        latitude: selectedPlace.latitude,
                        longitude: selectedPlace.longitude
                    )
                state.memberPlaces[state.currentMember, default: []].append(pinnedPlace)
                state.selectedMember = state.currentMember
                state.selectedPlace = nil
                state.selectedPinnedPlace = nil
                state.searchText = ""
                state.isMemberPlacesSheetPresented = true
                state.isBottomSheetExpanded = false
                let tripID = state.tripID
                return .run { send in
                    do {
                        try await placeClient.savePlace(tripID, pinnedPlace)
                    } catch {
                        await send(.placeMutationFailed(error.localizedDescription))
                    }
                }

            case let .pinnedPlaceTapped(place):
                state.isMemberPlacesSheetPresented = true
                state.selectedPinnedPlace = place
                state.searchText = place.name
                state.isBottomSheetExpanded = true
                state.isPlaceDetailsLoading = true
                state.selectedPlace = PlaceDetails(
                    id: place.id,
                    name: place.name,
                    address: place.description,
                    category: place.category,
                    rating: 0,
                    ratingCount: 0,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    photoData: place.photoData
                )
                let result = PlaceSearchResult(
                    id: place.id,
                    name: place.name,
                    address: place.description
                )
                return .run { send in
                    do {
                        let details = try await placeClient.fetchDetails(result)
                        await send(.pinnedPlaceDetailsResponse(place.id, details))
                    } catch {
                        await send(.pinnedPlaceDetailsFailed(place.id))
                    }
                }

            case let .pinnedPlaceDetailsResponse(placeID, details):
                guard state.selectedPinnedPlace?.id == placeID else { return .none }
                state.selectedPlace = details
                state.isPlaceDetailsLoading = false
                return .none

            case let .pinnedPlaceDetailsFailed(placeID):
                guard state.selectedPinnedPlace?.id == placeID else { return .none }
                state.isPlaceDetailsLoading = false
                return .none

            case let .deletePinnedPlaceButtonTapped(placeID):
                guard state.isViewingCurrentUser else { return .none }
                state.memberPlaces[state.currentMember, default: []].removeAll {
                    $0.id == placeID
                }
                if state.selectedPinnedPlace?.id == placeID {
                    state.selectedPinnedPlace = nil
                    state.selectedPlace = nil
                    state.searchText = ""
                    state.isPlaceDetailsLoading = false
                }
                let tripID = state.tripID
                return .run { send in
                    do {
                        try await placeClient.deletePlace(tripID, placeID)
                    } catch {
                        await send(.placeMutationFailed(error.localizedDescription))
                    }
                }

            case let .movePinnedPlace(sourceID, beforeID):
                guard state.isViewingCurrentUser else { return .none }
                var places = state.memberPlaces[state.currentMember, default: []]
                guard sourceID != beforeID,
                      let sourceIndex = places.firstIndex(where: { $0.id == sourceID })
                else { return .none }

                let place = places.remove(at: sourceIndex)
                let destinationIndex = beforeID.flatMap { beforeID in
                    places.firstIndex(where: { $0.id == beforeID })
                } ?? places.endIndex
                places.insert(place, at: destinationIndex)
                state.memberPlaces[state.currentMember] = places

                let tripID = state.tripID
                let reorderedPlaces = places
                return .run { send in
                    do {
                        try await placeClient.replacePlaces(tripID, reorderedPlaces)
                    } catch {
                        await send(.placeMutationFailed(error.localizedDescription))
                    }
                }

            case let .memberProfileTapped(member):
                guard state.participants.contains(where: {
                    $0.member == member && $0.hasJoined
                }) else { return .none }
                state.selectedMember = member
                state.selectedPlace = nil
                state.selectedPinnedPlace = nil
                state.searchText = ""
                state.isMemberPlacesSheetPresented = true
                state.isBottomSheetExpanded = true
                return loadMemberPlacesEffect(tripID: state.tripID)

            case .confirmButtonTapped:
                guard state.canConfirmPlaceSelection else { return .none }
                guard let index = state.participants.firstIndex(where: \.isCurrentUser) else {
                    return .none
                }

                state.participants[index].isConfirmed = true
                state.selectedPlace = nil
                state.selectedPinnedPlace = nil
                state.searchText = ""
                state.isMemberPlacesSheetPresented = false
                state.isBottomSheetExpanded = true
                state.isEditingConfirmedPlaces = false

                if state.haveAllParticipantsJoinedAndConfirmed {
                    state.isTimerRunning = false
                    state.hasSelectionEnded = true
                    state.completionAlert = .allMembersConfirmed
                    return .merge(
                        confirmPlacesEffect(tripID: state.tripID),
                        .cancel(id: "place-selection-timer")
                    )
                }
                return confirmPlacesEffect(tripID: state.tripID)

            case .confirmedPlacesEditButtonTapped:
                guard state.isShowingConfirmedPlaces else { return .none }
                state.isEditingConfirmedPlaces.toggle()
                return .none

            case let .deleteConfirmedPlaceButtonTapped(placeID):
                guard state.isEditingConfirmedPlaces else { return .none }
                for member in state.memberPlaces.keys {
                    state.memberPlaces[member, default: []].removeAll { $0.id == placeID }
                }
                return .none

            case .completionAlertConfirmButtonTapped:
                guard let completionAlert = state.completionAlert else { return .none }
                if completionAlert == .allMembersConfirmed,
                   !state.haveAllParticipantsJoinedAndConfirmed {
                    state.completionAlert = nil
                    return .none
                }
                state.completionAlert = nil
                return .send(.delegate(.proceedToAnalysis))

            case .timerTicked:
                guard state.remainingSeconds > 0 else { return .none }
                state.remainingSeconds -= 1
                if state.remainingSeconds == 0 {
                    state.isTimerRunning = false
                    state.hasSelectionEnded = true
                    state.isBottomSheetExpanded = true
                    state.isSearchPresented = false
                    state.completionAlert = .selectionTimeExpired
                    return .cancel(id: "place-selection-timer")
                }
                return .none

            case .moveCriteriaButtonTapped:
                return .none

            case let .placeDetailsResponse(details):
                guard state.selectedPinnedPlace == nil else { return .none }
                state.selectedPlace = details
                state.isPlaceDetailsLoading = false
                return .none

            case .placeDetailsFailed:
                guard state.selectedPinnedPlace == nil else { return .none }
                state.isPlaceDetailsLoading = false
                return .none

            case .searchDismissed, .placeSearch(.delegate(.close)):
                state.isSearchPresented = false
                return .none

            case let .placeSearch(.delegate(.placeSelected(result))):
                state.selectedPinnedPlace = nil
                state.searchText = result.name
                state.isSearchPresented = false
                state.isBottomSheetExpanded = true
                state.isPlaceDetailsLoading = true
                state.selectedPlace = PlaceDetails(
                    id: result.id,
                    name: result.name,
                    address: result.address,
                    category: "장소",
                    rating: 0,
                    ratingCount: 0,
                    latitude: 35.6764,
                    longitude: 139.6500,
                    photoData: []
                )
                return .run { send in
                    do {
                        await send(.placeDetailsResponse(try await placeClient.fetchDetails(result)))
                    } catch {
                        await send(.placeDetailsFailed)
                    }
                }

            case .placeSearch:
                return .none

            case .delegate:
                return .none
            }
        }

        Scope(state: \.placeSearch, action: \.placeSearch) {
            PlaceSearchFeature()
        }
    }

    private func loadMemberPlacesEffect(tripID: String) -> Effect<Action> {
        .run { send in
            do {
                await send(.memberPlacesResponse(try await placeClient.fetchMemberPlaces(tripID)))
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

    private func loadPlacePhotoEffect(_ place: PinnedPlace) -> Effect<Action> {
        .run { send in
            do {
                let result = PlaceSearchResult(
                    id: place.id,
                    name: place.name,
                    address: place.description
                )
                let details = try await placeClient.fetchDetails(result)
                await send(.placePhotoResponse(place.id, details.photoData))
            } catch {
                await send(.placePhotoResponse(place.id, []))
            }
        }
    }

    private func placeWithPhotoData(
        _ place: PinnedPlace,
        photoData: [Data]
    ) -> PinnedPlace {
        PinnedPlace(
            id: place.id,
            name: place.name,
            description: place.description,
            thumbnailName: "",
            category: place.category,
            photoData: photoData,
            latitude: place.latitude,
            longitude: place.longitude
        )
    }

    private func confirmPlacesEffect(tripID: String) -> Effect<Action> {
        .run { send in
            do {
                try await placeClient.confirmPlaces(tripID)
            } catch {
                await send(.placeMutationFailed(error.localizedDescription))
            }
        }
    }
}
