//
//  PlaceGroupingDetailFeature.swift
//  ddaddo
//

import ComposableArchitecture

struct PlaceGroupingDetailFeature: Reducer {
    enum Delegate: Equatable {
        case confirmed
        case joined
    }

    @ObservableState
    struct State: Equatable {
        var tripTitle = "도쿄 여행"
        var tripDates = "11월 22일 ~ 25일"
        var groupTitle = "신주쿠를 가게따"
        var members: [Member] = Member.preview
        var places: [Place] = Place.preview
        var isToastPresented = false
        var isOwnedGroup = true
        var selectedMemberIDs: Set<String> = ["tae", "header"]
        var isJoinConfirmationPresented = false

        var canJoin: Bool {
            selectedMemberIDs == ["juni"]
        }

        var canEditPlaces: Bool {
            isOwnedGroup && selectedMemberIDs == ["tae", "header"]
        }

        var showsEmptyState: Bool {
            selectedMemberIDs == ["grae"]
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
    }

    enum Action: Equatable {
        case backButtonTapped
        case memberTapped(String)
        case joinButtonTapped
        case joinConfirmationCancelTapped
        case joinConfirmationConfirmTapped
        case deletePlaceTapped(String)
        case placeMoved(sourceID: String, beforeID: String)
        case toastDismissed
        case confirmButtonTapped
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .memberTapped(id):
                switch id {
                case "tae", "header":
                    state.selectedMemberIDs = ["tae", "header"]
                case "juni":
                    state.selectedMemberIDs = ["juni"]
                case "grae":
                    state.selectedMemberIDs = ["grae"]
                default:
                    return .none
                }
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

            case let .deletePlaceTapped(id):
                guard state.canEditPlaces else { return .none }
                state.places.removeAll { $0.id == id }
                state.isToastPresented = true
                return .run { send in
                    try await Task.sleep(for: .seconds(2.5))
                    await send(.toastDismissed)
                }
                .cancellable(
                    id: "place-grouping-detail-toast",
                    cancelInFlight: true
                )

            case let .placeMoved(sourceID, beforeID):
                guard state.canEditPlaces else { return .none }
                guard
                    sourceID != beforeID,
                    let sourceIndex = state.places.firstIndex(where: { $0.id == sourceID }),
                    let destinationIndex = state.places.firstIndex(where: { $0.id == beforeID })
                else { return .none }

                let place = state.places.remove(at: sourceIndex)
                let adjustedDestination = sourceIndex < destinationIndex
                    ? destinationIndex - 1
                    : destinationIndex
                state.places.insert(place, at: adjustedDestination)
                return .none

            case .toastDismissed:
                state.isToastPresented = false
                return .none

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
