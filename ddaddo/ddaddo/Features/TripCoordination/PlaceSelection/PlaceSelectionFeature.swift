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
    struct Participant: Equatable, Identifiable, Sendable {
        let id: Int
        let member: TripMember
        let name: String
        let hasJoined: Bool
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
        var placeSearch = PlaceSearchFeature.State()

        init(
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
            "\(numberOfNights)박 \(numberOfDays)일 \(destinationName)여행"
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

        var canConfirmPlaceSelection: Bool {
            !memberPlaces[currentMember, default: []].isEmpty
                && !isCurrentUserConfirmed
                && !hasSelectionEnded
        }

        var isCurrentUserConfirmed: Bool {
            participants.first(where: \.isCurrentUser)?.isConfirmed == true
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

        var mapPlaces: [PinnedPlace] {
            isShowingConfirmedPlaces ? confirmedPlaces : displayedPlaces
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
            tripTitle: String,
            destinationName: String,
            tripStartDate: Date,
            tripEndDate: Date,
            participants: [Participant],
            remainingSeconds: Int
        ) {
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
                    thumbnailName: "DDMockPlaceVillage",
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
                    thumbnailName: "DDMockPlaceVillage",
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
                    thumbnailName: "DDMockPlaceVillage",
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
        case backButtonTapped
        case searchFieldTapped
        case searchTextChanged(String)
        case searchButtonTapped
        case dimmedBackgroundTapped
        case bottomSheetDragEnded(CGFloat)
        case clearSelectedPlaceButtonTapped
        case addSelectedPlaceButtonTapped
        case pinnedPlaceTapped(PinnedPlace)
        case pinnedPlaceDetailsResponse(String, PlaceDetails)
        case pinnedPlaceDetailsFailed(String)
        case deletePinnedPlaceButtonTapped(String)
        case memberProfileTapped(TripMember)
        case confirmButtonTapped
        case confirmedPlacesEditButtonTapped
        case deleteConfirmedPlaceButtonTapped(String)
        case timerTicked
        case moveCriteriaButtonTapped
        case placeDetailsResponse(PlaceDetails)
        case placeDetailsFailed
        case searchDismissed
        case placeSearch(PlaceSearchFeature.Action)
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isTimerRunning, !state.hasSelectionEnded else {
                    return .none
                }
                state.isTimerRunning = true
                return .run { send in
                    while !Task.isCancelled {
                        try await clock.sleep(for: .seconds(1))
                        await send(.timerTicked)
                    }
                }
                .cancellable(id: "place-selection-timer", cancelInFlight: true)

            case .backButtonTapped:
                return .none

            case .searchFieldTapped:
                state.selectedMember = state.currentMember
                state.isSearchPresented = true
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case .searchButtonTapped:
                state.selectedMember = state.currentMember
                state.selectedPinnedPlace = nil
                state.isBottomSheetExpanded = false
                state.isSearchPresented = true
                return .none

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

            case .clearSelectedPlaceButtonTapped:
                state.searchText = ""
                state.selectedPlace = nil
                state.selectedPinnedPlace = nil
                state.isPlaceDetailsLoading = false
                state.isBottomSheetExpanded = true
                return .none

            case .addSelectedPlaceButtonTapped:
                guard
                    state.canAddSelectedPlace,
                    let selectedPlace = state.selectedPlace
                else { return .none }

                state.memberPlaces[state.currentMember, default: []].append(
                    PinnedPlace(
                        id: selectedPlace.id,
                        name: selectedPlace.name,
                        description: selectedPlace.address,
                        thumbnailName: "DDMockPlaceVillage",
                        category: selectedPlace.category,
                        photoData: selectedPlace.photoData,
                        latitude: selectedPlace.latitude,
                        longitude: selectedPlace.longitude
                    )
                )
                state.selectedMember = state.currentMember
                state.selectedPlace = nil
                state.selectedPinnedPlace = nil
                state.searchText = ""
                state.isMemberPlacesSheetPresented = true
                state.isBottomSheetExpanded = false
                return .none

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
                return .none

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
                return .none

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
                return .none

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

            case .timerTicked:
                guard state.remainingSeconds > 0 else { return .none }
                state.remainingSeconds -= 1
                if state.remainingSeconds == 0 {
                    state.isTimerRunning = false
                    state.hasSelectionEnded = true
                    state.isBottomSheetExpanded = true
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
            }
        }

        Scope(state: \.placeSearch, action: \.placeSearch) {
            PlaceSearchFeature()
        }
    }
}
