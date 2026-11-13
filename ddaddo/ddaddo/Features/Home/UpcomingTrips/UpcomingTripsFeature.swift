//
//  UpcomingTripsFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct UpcomingTripsFeature: Reducer {
    enum Delegate: Equatable {
        case returnHome
        case proceedToAnalysis(PlaceSelectionFeature.State)
        case proceedToGrouping(PlaceSelectionFeature.State)
    }

    struct Trip: Equatable, Identifiable {
        let id: String
        let destination: String
        var destinationName: String? = nil
        let country: String
        let dateText: String
        var startDate: Date? = nil
        var endDate: Date? = nil
        let progress: UpcomingTripSnapshot.Progress

        var progressTitle: String {
            switch progress {
            case .placeSelection: "장소 핀 찍기"
            case .placeGrouping: "추천 그룹 확정하기"
            case .itinerary: "여행 계획"
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var trips: [Trip] = []
        var isLoadingTrips = false
        var isAddTripMenuPresented = false
        var isInviteCodeModalPresented = false
        var inviteCode = ""
        var isJoiningTrip = false
        var joinErrorMessage: String?
        var pendingDeletionTripID: Trip.ID?
        var isDeletingTrip = false
        var deletionErrorMessage: String?
        var isResettingDevelopmentData = false
        var resetDevelopmentDataMessage: String?
        var waitingForParticipants: WaitingForParticipantsFeature.State?
        var isWaitingForParticipantsPresented = false
        var pendingTripProgress: UpcomingTripSnapshot.Progress?

        var isJoinButtonEnabled: Bool {
            inviteCode.count == 6 && !isJoiningTrip
        }
    }

    @CasePathable
    enum Action {
        case onAppear
        case upcomingTripsResponse(Result<[UpcomingTripSnapshot], Error>)
        case backButtonTapped
        case addTripButtonTapped
        case addTripMenuDismissed
        case createTripButtonTapped
        case enterInviteCodeButtonTapped
        case inviteCodeChanged(String)
        case inviteCodeModalDismissed
        case joinTripButtonTapped
        case joinTripResponse(TripInvitationSnapshot)
        case joinTripFailed(String)
        case joinErrorDismissed
        case deleteButtonTapped(Trip.ID)
        case deleteCancelButtonTapped
        case deleteConfirmButtonTapped
        case deleteTripResponse(Trip.ID, Result<Void, Error>)
        case deletionErrorDismissed
        case resetDevelopmentDataButtonTapped
        case resetDevelopmentDataResponse(Result<Void, Error>)
        case resetDevelopmentDataMessageDismissed
        case waitingForParticipantsDismissed
        case waitingForParticipants(WaitingForParticipantsFeature.Action)
        case tripInvitationResponse(Result<TripInvitationSnapshot, Error>)
        case delegate(Delegate)
        case viewScheduleButtonTapped(Trip.ID)
    }

    @Dependency(\.tripClient) var tripClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoadingTrips else { return .none }
                state.isLoadingTrips = true
                return fetchUpcomingTripsEffect()

            case let .upcomingTripsResponse(.success(snapshots)):
                state.isLoadingTrips = false
                var trips: [Trip] = []
                for snapshot in snapshots {
                    trips.append(Self.makeTrip(from: snapshot))
                }
                state.trips = trips
                return .none

            case .upcomingTripsResponse(.failure):
                state.isLoadingTrips = false
                return .none

            case .backButtonTapped:
                state.isAddTripMenuPresented = false
                return .none

            case .addTripButtonTapped:
                state.isAddTripMenuPresented.toggle()
                return .none

            case .addTripMenuDismissed:
                state.isAddTripMenuPresented = false
                return .none

            case .createTripButtonTapped:
                state.isAddTripMenuPresented = false
                return .none

            case .enterInviteCodeButtonTapped:
                state.isAddTripMenuPresented = false
                state.inviteCode = ""
                state.isInviteCodeModalPresented = true
                return .none

            case let .inviteCodeChanged(code):
                state.inviteCode = String(code.filter(\.isNumber).prefix(6))
                return .none

            case .inviteCodeModalDismissed:
                guard !state.isJoiningTrip else { return .none }
                state.isInviteCodeModalPresented = false
                state.inviteCode = ""
                return .none

            case .joinTripButtonTapped:
                guard state.isJoinButtonEnabled else { return .none }
                state.isJoiningTrip = true
                state.joinErrorMessage = nil
                let inviteCode = state.inviteCode
                return .run { send in
                    do {
                        await send(.joinTripResponse(try await tripClient.joinTrip(inviteCode)))
                    } catch {
                        await send(.joinTripFailed(error.localizedDescription))
                    }
                }

            case let .joinTripResponse(snapshot):
                state.isJoiningTrip = false
                state.isInviteCodeModalPresented = false
                state.inviteCode = ""
                state.waitingForParticipants = WaitingForParticipantsFeature.State(snapshot: snapshot)
                state.isWaitingForParticipantsPresented = true
                return fetchUpcomingTripsEffect()

            case let .joinTripFailed(message):
                state.isJoiningTrip = false
                state.joinErrorMessage = message
                return .none

            case .joinErrorDismissed:
                state.joinErrorMessage = nil
                return .none

            case let .deleteButtonTapped(tripID):
                guard state.pendingDeletionTripID == nil,
                      state.trips.contains(where: { $0.id == tripID }) else { return .none }
                state.pendingDeletionTripID = tripID
                return .none

            case .deleteCancelButtonTapped:
                state.pendingDeletionTripID = nil
                return .none

            case .deleteConfirmButtonTapped:
                guard let tripID = state.pendingDeletionTripID,
                      !state.isDeletingTrip else { return .none }
                state.isDeletingTrip = true
                state.pendingDeletionTripID = nil
                return .run { send in
                    await send(
                        .deleteTripResponse(
                            tripID,
                            Result { try await tripClient.deleteUpcomingTrip(tripID) }
                        )
                    )
                }

            case let .deleteTripResponse(tripID, .success):
                state.isDeletingTrip = false
                state.trips.removeAll { $0.id == tripID }
                return .none

            case let .deleteTripResponse(_, .failure(error)):
                state.isDeletingTrip = false
                state.deletionErrorMessage = error.localizedDescription
                return .none

            case .deletionErrorDismissed:
                state.deletionErrorMessage = nil
                return .none

            case .resetDevelopmentDataButtonTapped:
                guard !state.isResettingDevelopmentData else { return .none }
                state.isResettingDevelopmentData = true
                state.resetDevelopmentDataMessage = nil
                return .run { send in
                    await send(
                        .resetDevelopmentDataResponse(
                            Result { try await tripClient.resetDevelopmentMockTrips() }
                        )
                    )
                }

            case .resetDevelopmentDataResponse(.success):
                state.isResettingDevelopmentData = false
                state.resetDevelopmentDataMessage = "Dev 목데이터를 초기 상태로 되돌렸어요."
                state.isLoadingTrips = true
                return fetchUpcomingTripsEffect()

            case let .resetDevelopmentDataResponse(.failure(error)):
                state.isResettingDevelopmentData = false
                state.resetDevelopmentDataMessage = error.localizedDescription
                return .none

            case .resetDevelopmentDataMessageDismissed:
                state.resetDevelopmentDataMessage = nil
                return .none

            case .waitingForParticipantsDismissed,
                 .waitingForParticipants(.backButtonTapped):
                state.isWaitingForParticipantsPresented = false
                return .none

            case .waitingForParticipants(.delegate(.returnHome)):
                state.isWaitingForParticipantsPresented = false
                return .merge(
                    fetchUpcomingTripsEffect(),
                    .send(.delegate(.returnHome))
                )

            case .waitingForParticipants(.delegate(.returnToUpcomingTrips)):
                state.isWaitingForParticipantsPresented = false
                return fetchUpcomingTripsEffect()

            case let .waitingForParticipants(.delegate(.proceedToAnalysis(placeSelection))):
                state.isWaitingForParticipantsPresented = false
                return .send(.delegate(.proceedToAnalysis(placeSelection)))

            case .waitingForParticipants:
                return .none

            case .delegate:
                return .none

            case let .viewScheduleButtonTapped(tripID):
                guard let trip = state.trips.first(where: { $0.id == tripID }) else {
                    return .none
                }
                guard trip.progress != .itinerary else { return .none }
                state.pendingTripProgress = trip.progress
                return .run { send in
                    await send(
                        .tripInvitationResponse(
                            Result { try await tripClient.fetchInvitation(tripID) }
                        )
                    )
                }

            case let .tripInvitationResponse(.success(snapshot)):
                let progress = state.pendingTripProgress
                state.pendingTripProgress = nil
                let waitingState = WaitingForParticipantsFeature.State(snapshot: snapshot)
                switch progress {
                case .placeSelection:
                    state.waitingForParticipants = waitingState
                    state.isWaitingForParticipantsPresented = true
                    return .none
                case .placeGrouping:
                    return .send(.delegate(.proceedToGrouping(waitingState.placeSelection)))
                case .itinerary, .none:
                    return .none
                }

            case .tripInvitationResponse(.failure):
                state.pendingTripProgress = nil
                return .none
            }
        }
        .ifLet(\.waitingForParticipants, action: \.waitingForParticipants) {
            WaitingForParticipantsFeature()
        }
    }

    private func fetchUpcomingTripsEffect() -> Effect<Action> {
        .run { send in
            await send(
                .upcomingTripsResponse(
                    Result { try await tripClient.fetchUpcomingTrips() }
                )
            )
        }
    }

    private static func makeTrip(from snapshot: UpcomingTripSnapshot) -> Trip {
        let destination = (englishCityNames[snapshot.destinationName] ?? snapshot.destinationName)
            .uppercased()
        let country = englishCountryNames[snapshot.countryName] ?? snapshot.countryName

        return Trip(
            id: snapshot.tripID,
            destination: destination,
            destinationName: snapshot.destinationName,
            country: country,
            dateText: dateText(from: snapshot.startDate, to: snapshot.endDate),
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            progress: snapshot.progress
        )
    }

    private static let englishCountryNames: [String: String] = [
        "일본": "Japan",
        "대만": "Taiwan",
        "중국": "China",
        "홍콩": "Hong Kong",
        "마카오": "Macau",
        "몽골": "Mongolia",
        "태국": "Thailand",
        "베트남": "Vietnam",
        "인도네시아": "Indonesia",
        "필리핀": "Philippines",
        "싱가포르": "Singapore",
        "말레이시아": "Malaysia",
        "프랑스": "France",
        "영국": "United Kingdom",
        "이탈리아": "Italy",
        "스페인": "Spain",
        "스위스": "Switzerland",
        "체코": "Czechia",
        "오스트리아": "Austria",
        "미국": "United States",
        "캐나다": "Canada",
        "호주": "Australia",
        "뉴질랜드": "New Zealand"
    ]

    private static let englishCityNames: [String: String] = [
        "도쿄": "Tokyo",
        "오사카": "Osaka",
        "교토": "Kyoto",
        "후쿠오카": "Fukuoka",
        "삿포로": "Sapporo",
        "오키나와": "Okinawa",
        "나고야": "Nagoya",
        "고베": "Kobe",
        "나라": "Nara",
        "다카마쓰": "Takamatsu",
        "요코하마": "Yokohama",
        "가나자와": "Kanazawa",
        "히로시마": "Hiroshima",
        "타이베이": "Taipei",
        "타이중": "Taichung",
        "가오슝": "Kaohsiung",
        "타이난": "Tainan",
        "상하이": "Shanghai",
        "베이징": "Beijing",
        "칭다오": "Qingdao",
        "청두": "Chengdu",
        "홍콩": "Hong Kong",
        "마카오": "Macau",
        "울란바토르": "Ulaanbaatar",
        "방콕": "Bangkok",
        "나트랑": "Nha Trang",
        "다낭": "Da Nang",
        "하노이": "Hanoi",
        "호찌민": "Ho Chi Minh City",
        "푸꾸옥": "Phu Quoc",
        "호이안": "Hoi An",
        "치앙마이": "Chiang Mai",
        "푸껫": "Phuket",
        "파타야": "Pattaya",
        "발리": "Bali",
        "세부": "Cebu",
        "마닐라": "Manila",
        "보라카이": "Boracay",
        "싱가포르": "Singapore",
        "쿠알라룸푸르": "Kuala Lumpur",
        "파리": "Paris",
        "런던": "London",
        "로마": "Rome",
        "피렌체": "Florence",
        "베네치아": "Venice",
        "밀라노": "Milan",
        "바르셀로나": "Barcelona",
        "마드리드": "Madrid",
        "취리히": "Zurich",
        "인터라켄": "Interlaken",
        "프라하": "Prague",
        "빈": "Vienna",
        "뉴욕": "New York",
        "로스앤젤레스": "Los Angeles",
        "샌프란시스코": "San Francisco",
        "라스베이거스": "Las Vegas",
        "시애틀": "Seattle",
        "시카고": "Chicago",
        "보스턴": "Boston",
        "워싱턴 D.C.": "Washington, D.C.",
        "샌디에이고": "San Diego",
        "호놀룰루": "Honolulu",
        "밴쿠버": "Vancouver",
        "토론토": "Toronto",
        "시드니": "Sydney",
        "멜버른": "Melbourne",
        "오클랜드": "Auckland"
    ]

    private static func dateText(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startMonth = calendar.component(.month, from: startDate)
        let startDay = calendar.component(.day, from: startDate)
        let startYear = calendar.component(.year, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)
        let endDay = calendar.component(.day, from: endDate)
        let yearPrefix = startYear > calendar.component(.year, from: Date())
            ? "\(startYear % 100)년 "
            : ""

        if startMonth == endMonth {
            return "\(yearPrefix)\(startMonth)월 \(startDay)일~\(endDay)일"
        }
        return "\(yearPrefix)\(startMonth)월 \(startDay)일~\(endMonth)월 \(endDay)일"
    }
}
