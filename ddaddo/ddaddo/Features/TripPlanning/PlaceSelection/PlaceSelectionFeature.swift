//
//  PlaceSelectionFeature.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture
import CoreGraphics

struct PlaceSelectionFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var searchText = ""
        var isBottomSheetExpanded = true
        var isSearchPresented = false
        var selectedPlace: PlaceDetails?
        var isPlaceDetailsLoading = false
        var selectedMember: TripMember = .tae
        var memberPlaces = Self.mockMemberPlaces
        var placeSearch = PlaceSearchFeature.State()

        var displayedPlaces: [PinnedPlace] {
            memberPlaces[selectedMember] ?? []
        }

        private static let mockMemberPlaces: [TripMember: [PinnedPlace]] = [
            .tae: [
                PinnedPlace(
                    id: "tae-restaurant",
                    name: "임연수 랜드",
                    description: "이 장소는 어쩌구 저쩌구에서 가장 유명한 맛집입니다. 임연수 구이가 가장 맛있습니다.",
                    thumbnailName: "DDMockPlaceRestaurant",
                    latitude: 35.6696,
                    longitude: 139.7051
                ),
                PinnedPlace(
                    id: "tae-frappe",
                    name: "도쿄 말차 프라페",
                    description: "한 번만 먹어본 사람은 없는 말차 프라페 맛집입니다. 바나나를 추가할 경우 100엔 추가됩니다.",
                    thumbnailName: "DDMockPlaceFrappe",
                    latitude: 35.6654,
                    longitude: 139.7101
                ),
                PinnedPlace(
                    id: "tae-village",
                    name: "스머프 빌리지",
                    description: "진짜 스머프가 살았던 곳입니다. 버섯 스프를 만들어 먹을 수 있습니다.",
                    thumbnailName: "DDMockPlaceVillage",
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
                    latitude: 35.6595,
                    longitude: 139.7005
                ),
                PinnedPlace(
                    id: "header-village",
                    name: "도쿄 골목 산책",
                    description: "조용한 골목과 작은 상점이 이어지는 산책 코스입니다.",
                    thumbnailName: "DDMockPlaceVillage",
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
                    latitude: 35.6673,
                    longitude: 139.7130
                ),
                PinnedPlace(
                    id: "grae-village",
                    name: "하라주쿠 스트리트",
                    description: "개성 있는 숍과 전시 공간이 모여 있는 거리입니다.",
                    thumbnailName: "DDMockPlaceVillage",
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
                    latitude: 35.6643,
                    longitude: 139.7067
                )
            ]
        ]
    }

    @CasePathable
    enum Action: Equatable {
        case backButtonTapped
        case searchFieldTapped
        case searchTextChanged(String)
        case searchButtonTapped
        case dimmedBackgroundTapped
        case bottomSheetDragEnded(CGFloat)
        case clearSelectedPlaceButtonTapped
        case memberProfileTapped(TripMember)
        case placeDetailsResponse(PlaceDetails)
        case placeDetailsFailed
        case searchDismissed
        case placeSearch(PlaceSearchFeature.Action)
    }

    @Dependency(\.placeClient) var placeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                return .none

            case .searchFieldTapped:
                state.isSearchPresented = true
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case .searchButtonTapped:
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
                state.isPlaceDetailsLoading = false
                state.isBottomSheetExpanded = true
                return .none

            case let .memberProfileTapped(member):
                state.selectedMember = member
                state.selectedPlace = nil
                state.searchText = ""
                return .none

            case let .placeDetailsResponse(details):
                state.selectedPlace = details
                state.isPlaceDetailsLoading = false
                return .none

            case .placeDetailsFailed:
                state.isPlaceDetailsLoading = false
                return .none

            case .searchDismissed, .placeSearch(.delegate(.close)):
                state.isSearchPresented = false
                return .none

            case let .placeSearch(.delegate(.placeSelected(result))):
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
