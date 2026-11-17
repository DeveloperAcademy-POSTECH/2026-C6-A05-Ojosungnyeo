#if DEBUG
import FirebaseCore
import FirebaseFirestore
import Foundation

enum DevelopmentMockTripService {
    private struct Member {
        let nickname: String
        let nicknameKey: String
        let avatar: ParticipantAvatar
    }

    private struct Place {
        let name: String
        let category: String
        let address: String
    }

    private struct Trip {
        let id: String
        let inviteCode: String
        let title: String
        let country: String
        let destination: String
        let startDate: Date
        let endDate: Date
        let transportation: String
        let maximumTravelMinutes: Int
        let memberPlaces: [[Place]]
    }

    private struct ResolvedMember {
        let uid: String
        let member: Member
    }

    private static let members = [
        Member(
            nickname: "헤더",
            nicknameKey: "999150ec9bb6ce141fed9c6666a1ba5f15641fdaca676919d2519c68bde470b3",
            avatar: .juni
        ),
        Member(
            nickname: "그레",
            nicknameKey: "630f3a1e31f8a3de46cb12acf791b26344b091c20fef93e8a7cae85d880a6822",
            avatar: .grae
        ),
        Member(
            nickname: "테이",
            nicknameKey: "31eef782e2c8ab07f90fc402d3786cbff8118a68773bdcbbe458940fa189b762",
            avatar: .tae
        ),
        Member(
            nickname: "하르딘",
            nicknameKey: "6aeccc3b91bb7b2bc44b46bdaa69246a63fe7953e4bfd506c009eddba5fd2039",
            avatar: .header
        )
    ]

    /// 부스에서 직접 조작하지 않는 Dev 계정은 장소 선택을 완료한 상태로 유지합니다.
    private static let preconfirmedPlaceSelectionNicknames: Set<String> = [
        "테이",
        "하르딘"
    ]

    /// 부스에서 직접 조작하지 않는 Dev 계정은 그룹 조율도 완료한 상태로 유지합니다.
    private static let preconfirmedGroupingNicknames: Set<String> = [
        "테이",
        "하르딘"
    ]

    static func reset() async throws {
        guard FirebaseApp.app()?.options.projectID == "ddaddodev" else {
            throw DevelopmentMockTripError.developmentBuildRequired
        }
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }

        let database = Firestore.firestore()
        let resolvedMembers = try await resolveMembers(database: database)
        let trips = mockTrips
        var resolvedPlacesByTripID: [String: [[[String: Any]]]] = [:]

        for trip in trips {
            resolvedPlacesByTripID[trip.id] = try await resolvePlaces(for: trip)
        }

        try await deleteExistingSeedData(database: database, trips: trips)

        let batch = database.batch()
        let allTripIDs = trips.map(\.id)
        let expiresAt = Date().addingTimeInterval(72 * 60 * 60)

        for trip in trips {
            let tripReference = database.collection("trips").document(trip.id)
            let inviteReference = database.collection("inviteCodes").document(trip.inviteCode)
            let tripMembers = Array(resolvedMembers.prefix(trip.memberPlaces.count))

            batch.setData(
                [
                    "ownerID": tripMembers[0].uid,
                    "title": trip.title,
                    "destinationIDs": [trip.destination.lowercased()],
                    "destinations": [[
                        "id": trip.destination.lowercased(),
                        "country": trip.country,
                        "name": trip.destination
                    ]],
                    "startAt": Timestamp(date: trip.startDate),
                    "endAt": Timestamp(date: trip.endDate),
                    "travelerCount": tripMembers.count,
                    "transportation": trip.transportation,
                    "maximumTravelMinutes": trip.maximumTravelMinutes,
                    "inviteCode": trip.inviteCode,
                    "inviteURL": inviteURL(code: trip.inviteCode, expiresAt: expiresAt),
                    "expiresAt": Timestamp(date: expiresAt),
                    "status": "waiting",
                    "isDevelopmentSeed": true,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: tripReference
            )
            batch.setData(
                [
                    "tripID": trip.id,
                    "active": true,
                    "expiresAt": Timestamp(date: expiresAt),
                    "isDevelopmentSeed": true,
                    "createdAt": FieldValue.serverTimestamp()
                ],
                forDocument: inviteReference
            )

            for (index, resolvedMember) in tripMembers.enumerated() {
                let places = resolvedPlacesByTripID[trip.id]?[index] ?? []
                let isPlaceSelectionConfirmed = preconfirmedPlaceSelectionNicknames
                    .contains(resolvedMember.member.nickname)
                let isGroupingConfirmed = preconfirmedGroupingNicknames
                    .contains(resolvedMember.member.nickname)
                var participantData: [String: Any] = [
                    "slotIndex": index,
                    "uid": resolvedMember.uid,
                    "name": resolvedMember.member.nickname,
                    "avatarName": resolvedMember.member.avatar.rawValue,
                    "role": index == 0 ? "owner" : "member",
                    "status": "joined",
                    "selectedPlaces": places,
                    "placeSelectionConfirmed": isPlaceSelectionConfirmed,
                    "groupingConfirmed": isGroupingConfirmed,
                    "confirmedGroupIDs": [],
                    "joinedGroupIDs": [],
                    "joinedAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                if isGroupingConfirmed {
                    participantData["groupingConfirmedAt"] = FieldValue.serverTimestamp()
                }
                batch.setData(
                    participantData,
                    forDocument: tripReference
                        .collection("participants")
                        .document(resolvedMember.uid)
                )
            }

            batch.deleteDocument(tripReference.collection("itinerary").document("current"))
        }

        for resolvedMember in resolvedMembers {
            let userReference = database.collection("users").document(resolvedMember.uid)
            let userDocument = try await userReference.getDocument()
            let existingJoined = userDocument.get("joinedTripIDs") as? [String] ?? []
            let existingDismissed = userDocument.get("dismissedTripIDs") as? [String] ?? []
            let memberTripIDs = trips
                .filter { $0.memberPlaces.count > members.firstIndex(where: { $0.nicknameKey == resolvedMember.member.nicknameKey })! }
                .map(\.id)
            let joined = Array(Set(existingJoined.filter { !allTripIDs.contains($0) } + memberTripIDs)).sorted()
            let dismissed = existingDismissed.filter { !allTripIDs.contains($0) }

            batch.setData(
                [
                    "avatarName": resolvedMember.member.avatar.rawValue,
                    "joinedTripIDs": joined,
                    "dismissedTripIDs": dismissed,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: userReference,
                merge: true
            )
        }

        try await batch.commit()
    }

    private static func deleteExistingSeedData(
        database: Firestore,
        trips: [Trip]
    ) async throws {
        for trip in trips {
            let tripReference = database.collection("trips").document(trip.id)
            let participants = try await tripReference.collection("participants").getDocuments()
            let itinerary = try await tripReference.collection("itinerary").getDocuments()
            let batch = database.batch()

            for participant in participants.documents {
                let places = try await participant.reference.collection("places").getDocuments()
                for place in places.documents {
                    batch.deleteDocument(place.reference)
                }
                batch.deleteDocument(participant.reference)
            }
            for itineraryDocument in itinerary.documents {
                batch.deleteDocument(itineraryDocument.reference)
            }

            batch.deleteDocument(tripReference)
            batch.deleteDocument(database.collection("inviteCodes").document(trip.inviteCode))
            try await batch.commit()
        }
    }

    private static func resolveMembers(database: Firestore) async throws -> [ResolvedMember] {
        var result: [ResolvedMember] = []
        for member in members {
            let nicknameDocument = try await database
                .collection("nicknames")
                .document(member.nicknameKey)
                .getDocument()
            let indexedUID = nicknameDocument.get("uid") as? String
            let uid: String?
            if let indexedUID {
                uid = indexedUID
            } else {
                uid = try await database.collection("users")
                    .whereField("nicknameKey", isEqualTo: member.nicknameKey)
                    .limit(to: 1)
                    .getDocuments()
                    .documents
                    .first?
                    .documentID
            }
            guard let uid else {
                throw DevelopmentMockTripError.memberNotFound(member.nickname)
            }
            result.append(ResolvedMember(uid: uid, member: member))
        }
        return result
    }

    private static func resolvePlaces(for trip: Trip) async throws -> [[[String: Any]]] {
        let placesService = GooglePlacesService()
        var cache: [String: [String: Any]] = [:]
        var result: [[[String: Any]]] = []

        for places in trip.memberPlaces {
            var memberPlaces: [[String: Any]] = []
            for place in places {
                let cacheKey = "\(place.name)|\(place.address)"
                if let cached = cache[cacheKey] {
                    var value = cached
                    value["category"] = place.category
                    memberPlaces.append(value)
                    continue
                }

                do {
                    let value = try await resolvePlace(
                        place,
                        destination: trip.destination,
                        placesService: placesService
                    )
                    cache[cacheKey] = value
                    memberPlaces.append(value)
                } catch {
                    // Dev 시드는 실제 Google Places 좌표를 확인한 장소만 저장합니다.
                    continue
                }
            }
            result.append(memberPlaces)
        }
        return result
    }

    private static func resolvePlace(
        _ place: Place,
        destination: String,
        placesService: GooglePlacesService
    ) async throws -> [String: Any] {
        let queries = [
            "\(place.name) \(place.address)",
            place.address,
            "\(place.name) \(destination)"
        ]
        var lastError: Error?

        for query in queries {
            do {
                guard let suggestion = try await placesService.autocomplete(query: query).first else {
                    continue
                }
                let details = try await placesService.fetchDetails(for: suggestion)
                return placeData(
                    id: details.id,
                    place: place,
                    latitude: details.latitude,
                    longitude: details.longitude
                )
            } catch {
                lastError = error
            }
        }

        throw DevelopmentMockTripError.placeLookupFailed(
            place.name,
            lastError?.localizedDescription
        )
    }

    private static func placeData(
        id: String,
        place: Place,
        latitude: Double,
        longitude: Double
    ) -> [String: Any] {
        [
            "id": id,
            "name": place.name,
            "description": place.address,
            "category": place.category,
            "latitude": latitude,
            "longitude": longitude
        ]
    }

    private static func inviteURL(code: String, expiresAt: Date) -> String {
        var components = URLComponents(string: "https://ddaddo-web.vercel.app/invite")!
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "endTime", value: ISO8601DateFormatter().string(from: expiresAt))
        ]
        return components.url!.absoluteString
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

private enum DevelopmentMockTripError: LocalizedError {
    case developmentBuildRequired
    case memberNotFound(String)
    case placeLookupFailed(String, String?)

    var errorDescription: String? {
        switch self {
        case .developmentBuildRequired:
            "Dev Firebase에 연결된 앱에서만 목데이터를 초기화할 수 있어요."
        case let .memberNotFound(nickname):
            "Dev Firebase에서 \(nickname) 계정을 찾지 못했어요."
        case let .placeLookupFailed(place, message):
            if let message, !message.isEmpty {
                "\(place)의 실제 좌표를 가져오지 못했어요. \(message)"
            } else {
                "\(place)의 실제 좌표를 가져오지 못했어요."
            }
        }
    }
}

private extension DevelopmentMockTripService {
    private static var mockTrips: [Trip] {
        [tokyo, shanghai, newYork, paris, sydney, vancouver]
    }

    private static func places(_ values: [(String, String, String)]) -> [Place] {
        values.map { Place(name: $0.0, category: $0.1, address: $0.2) }
    }

    private static let tokyo = Trip(
        id: "dev-seed-trip-tokyo",
        inviteCode: "111111",
        title: "3박 4일 도쿄 여행",
        country: "일본",
        destination: "도쿄",
        startDate: makeDate(year: 2026, month: 11, day: 24),
        endDate: makeDate(year: 2026, month: 11, day: 27),
        transportation: Transportation.publicTransit.rawValue,
        maximumTravelMinutes: 30,
        memberPlaces: [
            places([
                ("센소지", "문화", "Senso-ji Asakusa"),
                ("나카미세 거리", "간식·쇼핑", "Nakamise-dori Asakusa"),
                ("일본과학미래관", "과학 체험", "Miraikan Odaiba"),
                ("도쿄 조이폴리스", "게임·VR", "Tokyo Joypolis Odaiba")
            ]),
            places([
                ("센소지", "문화", "Senso-ji Asakusa"),
                ("나카미세 거리", "간식·쇼핑", "Nakamise-dori Asakusa"),
                ("라포레 하라주쿠", "패션", "Laforet Harajuku"),
                ("키디랜드 하라주쿠점", "캐릭터 굿즈", "Kiddy Land Harajuku")
            ]),
            places([
                ("센소지", "문화", "Senso-ji Asakusa"),
                ("나카미세 거리", "간식·쇼핑", "Nakamise-dori Asakusa"),
                ("일본과학미래관", "과학 체험", "Miraikan Odaiba"),
                ("도쿄 조이폴리스", "게임·VR", "Tokyo Joypolis Odaiba")
            ]),
            places([
                ("센소지", "문화", "Senso-ji Asakusa"),
                ("나카미세 거리", "간식·쇼핑", "Nakamise-dori Asakusa"),
                ("라포레 하라주쿠", "패션", "Laforet Harajuku"),
                ("키디랜드 하라주쿠점", "캐릭터 굿즈", "Kiddy Land Harajuku")
            ])
        ]
    )

    private static let shanghai = Trip(
        id: "dev-seed-trip-shanghai",
        inviteCode: "222222",
        title: "3박 4일 상하이 여행",
        country: "중국",
        destination: "상하이",
        startDate: makeDate(year: 2026, month: 12, day: 3),
        endDate: makeDate(year: 2026, month: 12, day: 6),
        transportation: Transportation.publicTransit.rawValue,
        maximumTravelMinutes: 30,
        memberPlaces: [
            places([
                ("와이탄 전망대", "전망", "The Bund Viewing Platform Shanghai"),
                ("와이바이두 다리", "건축", "Waibaidu Bridge Shanghai"),
                ("팡성교", "전망", "Fangsheng Bridge Zhujiajiao"),
                ("청대 우체국", "역사", "Qing Dynasty Post Office Zhujiajiao")
            ]),
            places([
                ("와이탄 전망대", "전망", "The Bund Viewing Platform Shanghai"),
                ("와이바이두 다리", "건축", "Waibaidu Bridge Shanghai"),
                ("상하이 디즈니랜드", "테마파크", "Shanghai Disneyland"),
                ("디즈니타운", "쇼핑·맛집", "Disneytown Shanghai Disney Resort"),
                ("월드 오브 디즈니 스토어", "굿즈", "World of Disney Store Shanghai Disney Resort"),
                ("위싱 스타 파크", "호숫가 산책", "Wishing Star Park Shanghai Disney Resort")
            ]),
            places([
                ("와이탄 전망대", "전망", "The Bund Viewing Platform Shanghai"),
                ("와이바이두 다리", "건축", "Waibaidu Bridge Shanghai"),
                ("팡성교", "전망", "Fangsheng Bridge Zhujiajiao"),
                ("청대 우체국", "역사", "Qing Dynasty Post Office Zhujiajiao")
            ]),
            places([
                ("와이탄 전망대", "전망", "The Bund Viewing Platform Shanghai"),
                ("와이바이두 다리", "건축", "Waibaidu Bridge Shanghai"),
                ("상하이 디즈니랜드", "테마파크", "Shanghai Disneyland"),
                ("디즈니타운", "쇼핑·맛집", "Disneytown Shanghai Disney Resort"),
                ("월드 오브 디즈니 스토어", "굿즈", "World of Disney Store Shanghai Disney Resort"),
                ("위싱 스타 파크", "호숫가 산책", "Wishing Star Park Shanghai Disney Resort")
            ])
        ]
    )

    private static let newYork = Trip(
        id: "dev-seed-trip-new-york",
        inviteCode: "333333",
        title: "6박 7일 뉴욕 여행",
        country: "미국",
        destination: "뉴욕",
        startDate: makeDate(year: 2027, month: 4, day: 12),
        endDate: makeDate(year: 2027, month: 4, day: 18),
        transportation: Transportation.publicTransit.rawValue,
        maximumTravelMinutes: 45,
        memberPlaces: [
            places([
                ("메트 클로이스터스", "중세미술", "The Met Cloisters New York"),
                ("포트 트라이언 공원", "전망", "Fort Tryon Park New York"),
                ("다이크먼 팜하우스 박물관", "지역사", "Dyckman Farmhouse Museum New York"),
                ("인우드 힐 공원", "자연", "Inwood Hill Park New York"),
                ("뉴욕 아쿠아리움", "해양생물", "New York Aquarium Coney Island"),
                ("코니아일랜드 보드워크", "바닷가 산책", "Riegelmann Boardwalk at Stillwell Avenue Brooklyn"),
                ("패러슈트 점프", "랜드마크", "Parachute Jump Coney Island"),
                ("코니아일랜드 박물관", "지역사", "Coney Island Museum Brooklyn")
            ]),
            places([
                ("메트 클로이스터스", "중세미술", "The Met Cloisters New York"),
                ("포트 트라이언 공원", "전망", "Fort Tryon Park New York"),
                ("유나이티드 팰리스", "공연·건축", "United Palace Washington Heights New York"),
                ("포트 워싱턴 퍼블릭 하우스", "맛집", "Fort Washington Public House New York"),
                ("뉴욕 아쿠아리움", "해양생물", "New York Aquarium Coney Island"),
                ("코니아일랜드 보드워크", "바닷가 산책", "Riegelmann Boardwalk at Stillwell Avenue Brooklyn"),
                ("루나 파크", "놀이공원", "Luna Park in Coney Island"),
                ("네이선스 페이머스 본점", "맛집", "Nathan's Famous 1310 Surf Avenue Brooklyn")
            ])
        ]
    )

    private static let paris = Trip(
        id: "dev-seed-trip-paris",
        inviteCode: "444444",
        title: "6박 7일 파리 여행",
        country: "프랑스",
        destination: "파리",
        startDate: makeDate(year: 2027, month: 5, day: 10),
        endDate: makeDate(year: 2027, month: 5, day: 16),
        transportation: Transportation.publicTransit.rawValue,
        maximumTravelMinutes: 30,
        memberPlaces: [
            places([
                ("카르나발레 박물관", "박물관", "Musee Carnavalet Paris"),
                ("보주 광장", "산책", "Place des Vosges Paris"),
                ("라스 뒤 팔라펠", "맛집", "L'As du Fallafel Paris"),
                ("루이비통 재단 미술관", "현대미술", "Fondation Louis Vuitton Paris"),
                ("아클리마타시옹 정원", "놀이공원", "Jardin d'Acclimatation Paris"),
                ("바가텔 공원", "정원", "Parc de Bagatelle Paris"),
                ("프레 카틀랑 정원", "산책", "Jardin du Pre Catelan Paris"),
                ("샬레 데 질", "호숫가 식사", "Le Chalet des Iles Bois de Boulogne Paris"),
                ("오퇴유 온실 정원", "식물원", "Jardin des Serres d'Auteuil Paris")
            ]),
            places([
                ("카르나발레 박물관", "박물관", "Musee Carnavalet Paris"),
                ("보주 광장", "산책", "Place des Vosges Paris"),
                ("라스 뒤 팔라펠", "맛집", "L'As du Fallafel Paris"),
                ("과학산업관", "과학 체험", "Cite des sciences et de l'industrie Paris"),
                ("라 제오드", "영화·건축", "La Geode Paris"),
                ("파리 필하모니", "공연", "Philharmonie de Paris"),
                ("그랑드 알 드 라 빌레트", "전시", "Grande Halle de la Villette Paris"),
                ("빌레트 공원", "산책", "Parc de la Villette Paris"),
                ("붐붐 빌레트 푸드홀", "맛집", "Boom Boom Villette Paris")
            ]),
            places([
                ("카르나발레 박물관", "박물관", "Musee Carnavalet Paris"),
                ("보주 광장", "산책", "Place des Vosges Paris"),
                ("라스 뒤 팔라펠", "맛집", "L'As du Fallafel Paris"),
                ("루이비통 재단 미술관", "현대미술", "Fondation Louis Vuitton Paris"),
                ("아클리마타시옹 정원", "놀이공원", "Jardin d'Acclimatation Paris"),
                ("바가텔 공원", "정원", "Parc de Bagatelle Paris"),
                ("프레 카틀랑 정원", "산책", "Jardin du Pre Catelan Paris"),
                ("샬레 데 질", "호숫가 식사", "Le Chalet des Iles Bois de Boulogne Paris"),
                ("오퇴유 온실 정원", "식물원", "Jardin des Serres d'Auteuil Paris")
            ]),
            places([
                ("카르나발레 박물관", "박물관", "Musee Carnavalet Paris"),
                ("보주 광장", "산책", "Place des Vosges Paris"),
                ("라스 뒤 팔라펠", "맛집", "L'As du Fallafel Paris"),
                ("과학산업관", "과학 체험", "Cite des sciences et de l'industrie Paris"),
                ("라 제오드", "영화·건축", "La Geode Paris"),
                ("파리 필하모니", "공연", "Philharmonie de Paris"),
                ("그랑드 알 드 라 빌레트", "전시", "Grande Halle de la Villette Paris"),
                ("빌레트 공원", "산책", "Parc de la Villette Paris"),
                ("붐붐 빌레트 푸드홀", "맛집", "Boom Boom Villette Paris")
            ])
        ]
    )

    private static let sydney = Trip(
        id: "dev-seed-trip-sydney",
        inviteCode: "555555",
        title: "5박 6일 시드니 여행",
        country: "호주",
        destination: "시드니",
        startDate: makeDate(year: 2027, month: 3, day: 16),
        endDate: makeDate(year: 2027, month: 3, day: 21),
        transportation: Transportation.publicTransit.rawValue,
        maximumTravelMinutes: 30,
        memberPlaces: [
            places([
                ("시드니 오페라하우스", "랜드마크", "Sydney Opera House"),
                ("시드니 현대미술관", "현대미술", "Museum of Contemporary Art Australia Sydney"),
                ("더 록스 마켓", "쇼핑·먹거리", "The Rocks Markets Sydney"),
                ("맨리 비치", "해변", "Manly Beach Sydney"),
                ("셸리 비치", "자연", "Shelly Beach Manly NSW"),
                ("맨리 미술관·박물관", "전시", "Manly Art Gallery & Museum"),
                ("페어리 바워 풀", "수변 전망", "Fairy Bower Pool Manly"),
                ("맨리 코르소", "상점가", "The Corso Manly")
            ]),
            places([
                ("시드니 오페라하우스", "랜드마크", "Sydney Opera House"),
                ("시드니 현대미술관", "현대미술", "Museum of Contemporary Art Australia Sydney"),
                ("더 록스 마켓", "쇼핑·먹거리", "The Rocks Markets Sydney"),
                ("웨스트필드 패러매타", "쇼핑", "Westfield Parramatta"),
                ("패러매타 스퀘어", "맛집", "Parramatta Square NSW"),
                ("처치 스트리트 잇 스트리트", "맛집", "Eat Street Church Street Parramatta"),
                ("패러매타 리버사이드 시어터", "공연", "Riverside Theatres Parramatta"),
                ("패러매타 공원", "산책", "Parramatta Park NSW")
            ]),
            places([
                ("시드니 오페라하우스", "랜드마크", "Sydney Opera House"),
                ("시드니 현대미술관", "현대미술", "Museum of Contemporary Art Australia Sydney"),
                ("더 록스 마켓", "쇼핑·먹거리", "The Rocks Markets Sydney"),
                ("맨리 비치", "해변", "Manly Beach Sydney"),
                ("셸리 비치", "자연", "Shelly Beach Manly NSW"),
                ("맨리 미술관·박물관", "전시", "Manly Art Gallery & Museum"),
                ("페어리 바워 풀", "수변 전망", "Fairy Bower Pool Manly"),
                ("맨리 코르소", "상점가", "The Corso Manly")
            ]),
            places([
                ("시드니 오페라하우스", "랜드마크", "Sydney Opera House"),
                ("시드니 현대미술관", "현대미술", "Museum of Contemporary Art Australia Sydney"),
                ("더 록스 마켓", "쇼핑·먹거리", "The Rocks Markets Sydney"),
                ("웨스트필드 패러매타", "쇼핑", "Westfield Parramatta"),
                ("패러매타 스퀘어", "맛집", "Parramatta Square NSW"),
                ("처치 스트리트 잇 스트리트", "맛집", "Eat Street Church Street Parramatta"),
                ("패러매타 리버사이드 시어터", "공연", "Riverside Theatres Parramatta"),
                ("패러매타 공원", "산책", "Parramatta Park NSW")
            ])
        ]
    )

    private static let vancouver = Trip(
        id: "dev-seed-trip-vancouver",
        inviteCode: "666666",
        title: "5박 6일 밴쿠버 여행",
        country: "캐나다",
        destination: "밴쿠버",
        startDate: makeDate(year: 2026, month: 12, day: 14),
        endDate: makeDate(year: 2026, month: 12, day: 19),
        transportation: Transportation.publicTransit.rawValue,
        maximumTravelMinutes: 30,
        memberPlaces: [
            places([
                ("그랜빌 아일랜드 퍼블릭 마켓", "맛집", "Granville Island Public Market Vancouver"),
                ("넷 로프트", "공예·쇼핑", "Net Loft Granville Island Vancouver"),
                ("UBC 인류학박물관", "박물관", "Museum of Anthropology at UBC Vancouver"),
                ("니토베 기념정원", "정원", "Nitobe Memorial Garden UBC Vancouver"),
                ("비티 생물다양성 박물관", "과학·자연", "Beaty Biodiversity Museum UBC Vancouver"),
                ("스티브스턴 피셔맨스 워프", "해산물", "Steveston Fisherman's Wharf Richmond BC"),
                ("걸프 오브 조지아 캐너리", "어업 역사", "Gulf of Georgia Cannery Richmond BC"),
                ("브리타니아 조선소", "수변 산책·역사", "Britannia Shipyards National Historic Site Richmond BC")
            ]),
            places([
                ("그랜빌 아일랜드 퍼블릭 마켓", "맛집", "Granville Island Public Market Vancouver"),
                ("넷 로프트", "공예·쇼핑", "Net Loft Granville Island Vancouver"),
                ("론즈데일 키 마켓", "맛집·쇼핑", "Lonsdale Quay Market North Vancouver"),
                ("폴리곤 갤러리", "사진·전시", "The Polygon Gallery North Vancouver"),
                ("쉽야즈", "수변 광장", "The Shipyards North Vancouver"),
                ("스티브스턴 피셔맨스 워프", "해산물", "Steveston Fisherman's Wharf Richmond BC"),
                ("걸프 오브 조지아 캐너리", "어업 역사", "Gulf of Georgia Cannery Richmond BC"),
                ("브리타니아 조선소", "수변 산책·역사", "Britannia Shipyards National Historic Site Richmond BC")
            ]),
            places([
                ("그랜빌 아일랜드 퍼블릭 마켓", "맛집", "Granville Island Public Market Vancouver"),
                ("넷 로프트", "공예·쇼핑", "Net Loft Granville Island Vancouver"),
                ("UBC 인류학박물관", "박물관", "Museum of Anthropology at UBC Vancouver"),
                ("니토베 기념정원", "정원", "Nitobe Memorial Garden UBC Vancouver"),
                ("비티 생물다양성 박물관", "과학·자연", "Beaty Biodiversity Museum UBC Vancouver"),
                ("론즈데일 키 마켓", "맛집·쇼핑", "Lonsdale Quay Market North Vancouver"),
                ("폴리곤 갤러리", "사진·전시", "The Polygon Gallery North Vancouver"),
                ("쉽야즈", "수변 광장", "The Shipyards North Vancouver")
            ])
        ]
    )
}
#endif

