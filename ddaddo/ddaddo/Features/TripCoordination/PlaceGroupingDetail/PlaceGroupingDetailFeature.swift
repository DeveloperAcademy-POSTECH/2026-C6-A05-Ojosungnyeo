//
//  PlaceGroupingDetailFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct PlaceGroupingDetailFeature: Reducer {
    enum Delegate: Equatable {
        case confirmed
        case joined
        case placesReordered([String])
    }

    @ObservableState
    struct State: Equatable {
        var tripTitle = "도쿄 여행"
        var tripDates = "11월 22일 ~ 25일"
        var groupTitle = "신주쿠를 가게따"
        var members: [Member] = Member.preview
        var places: [Place] = Place.preview
        var isOwnedGroup = true
        var selectedMemberIDs: Set<String> = ["tae", "header"]
        var groupMemberIDs: Set<String> = ["tae", "header"]
        var preferenceCategories: [String] = ["쇼핑", "디저트"]
        var currentMemberID = "juni"
        var isJoinConfirmationPresented = false

        var canJoin: Bool {
            !groupMemberIDs.contains(currentMemberID)
        }

        var canEditPlaces: Bool {
            isOwnedGroup && selectedMemberIDs == groupMemberIDs
        }

        var showsEmptyState: Bool {
            selectedMemberIDs.isDisjoint(with: groupMemberIDs)
                || places.isEmpty
        }

        init() {}

        init(
            tripTitle: String,
            tripDates: String,
            group: PlaceGroupingFeature.RecommendedGroup,
            allMembers: [PlaceGroupingFeature.Member],
            currentMemberID: String
        ) {
            self.tripTitle = tripTitle
            self.tripDates = tripDates
            groupTitle = group.title == "자유시간 · 합류 확인"
                ? group.title
                : "\(group.title)를 가게따"
            members = allMembers.map { member in
                Member(
                    id: member.id,
                    name: member.name,
                    character: member.avatar,
                    isActive: group.memberIDs.contains(member.id)
                )
            }
            places = group.places.map { place in
                Place(
                    id: place.id,
                    title: place.name,
                    address: place.description,
                    imageName: place.thumbnailName,
                    photoData: place.photoData.first
                )
            }
            groupMemberIDs = Set(group.memberIDs)
            selectedMemberIDs = Set(group.memberIDs)
            preferenceCategories = group.categories
            self.currentMemberID = currentMemberID
            isOwnedGroup = group.memberIDs.contains(currentMemberID)
        }
    }

    struct Member: Equatable, Identifiable {
        let id: String
        let name: String
        let character: DDMiniHeadAvatar.Character
        let isActive: Bool

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.character.rawValue == rhs.character.rawValue
                && lhs.isActive == rhs.isActive
        }
    }

    struct Place: Equatable, Identifiable {
        let id: String
        let title: String
        let address: String
        let imageName: String
        var photoData: Data? = nil
    }

    enum Action: Equatable {
        case backButtonTapped
        case memberTapped(String)
        case joinButtonTapped
        case joinConfirmationCancelTapped
        case joinConfirmationConfirmTapped
        case placeMoved(sourceID: String, beforeID: String?)
        case confirmButtonTapped
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .memberTapped(id):
                guard state.members.contains(where: { $0.id == id }) else { return .none }
                state.selectedMemberIDs = state.groupMemberIDs.contains(id)
                    ? state.groupMemberIDs
                    : [id]
                return .none

            case .joinButtonTapped:
                guard state.canJoin else { return .none }
                state.isJoinConfirmationPresented = true
                return .none

            case .joinConfirmationCancelTapped:
                state.isJoinConfirmationPresented = false
                return .none

            case .joinConfirmationConfirmTapped:
                state.isJoinConfirmationPresented = false
                return .send(.delegate(.joined))

            case let .placeMoved(sourceID, beforeID):
                guard state.canEditPlaces else { return .none }
                guard sourceID != beforeID,
                      let sourceIndex = state.places.firstIndex(where: { $0.id == sourceID })
                else { return .none }

                let place = state.places.remove(at: sourceIndex)
                if let beforeID,
                   let destinationIndex = state.places.firstIndex(where: { $0.id == beforeID }) {
                    state.places.insert(place, at: destinationIndex)
                } else {
                    state.places.append(place)
                }
                return .send(.delegate(.placesReordered(state.places.map(\.id))))

            case .confirmButtonTapped:
                return .send(.delegate(.confirmed))

            case .backButtonTapped, .delegate:
                return .none
            }
        }
    }
}

extension PlaceGroupingDetailFeature.Member {
    fileprivate static let preview: [Self] = [
        .init(id: "tae", name: "테이", character: .tae, isActive: true),
        .init(id: "header", name: "헤더", character: .header, isActive: true),
        .init(id: "juni", name: "주니", character: .juni, isActive: false),
        .init(id: "grae", name: "그레", character: .grae, isActive: false),
    ]
}

extension PlaceGroupingDetailFeature.Place {
    fileprivate static let preview: [Self] = [
        .init(
            id: "tokyo-station-shopping",
            title: "도쿄 타워",
            address: "2 Chome-1004 Tokyo, Chuo\nWard, 福岡市 福岡県 810-0001",
            imageName: "DDPlaceTokyoStation"
        ),
        .init(
            id: "tokyo-market-street",
            title: "도쿄 시장",
            address: "89G2+WH, Tsushima, Nagasaki\n817-1105",
            imageName: "DDPlaceTokyoMarket"
        ),
        .init(
            id: "matcha-frappe-park",
            title: "말차 파크",
            address: "〒150-0001 Tokyo, Shibuya,\n6 Chome−20−10 South 2F",
            imageName: "DDPlaceMatchaPark"
        ),
        .init(
            id: "stussy-tokyo",
            title: "스투시 도쿄점",
            address: "89G2+WH, Tsushima, Nagasaki\n817-1105",
            imageName: "DDPlaceStussyTokyo"
        ),
    ]
}
