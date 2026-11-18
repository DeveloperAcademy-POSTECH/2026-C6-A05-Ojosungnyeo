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
        let memberNicknames: [String]
        let memberPlaces: [[Place]]
    }

    private struct ResolvedMember {
        let uid: String
        let member: Member
    }

    private struct ItineraryCourseSeed {
        let id: Int
        let title: String
        let placeNames: [String]
        let memberIndexes: [Int]
        let durationMinutes: Int
    }

    private struct ItineraryScheduleSeed {
        let id: Int
        let courseID: Int
        let startMinuteOfDay: Int
        let branchGroupID: Int?
        let orderIndex: Int
    }

    private static let members = [
        Member(
            nickname: "헤더",
            nicknameKey: "999150ec9bb6ce141fed9c6666a1ba5f15641fdaca676919d2519c68bde470b3",
            avatar: .header
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
            avatar: .juni
        ),
        Member(
            nickname: "주니",
            nicknameKey: "94220151a77fe8912c14b07a291e9df4ea598d63838cea9b077a068974cdea71",
            avatar: .tae
        ),
        Member(
            nickname: "세니",
            nicknameKey: "cf2417cf73a770df6a0ae52f12cf63b4b66bc81a4ca8b9151ead075ee7f98e99",
            avatar: .juni
        )
    ]

    /// 부스에서 직접 조작하지 않는 Dev 계정은 장소 선택을 완료한 상태로 유지합니다.
    private static let preconfirmedPlaceSelectionNicknames: Set<String> = [
        "그레",
        "헤더"
    ]

    /// 부스에서 직접 조작하지 않는 Dev 계정은 그룹 조율도 완료한 상태로 유지합니다.
    private static let preconfirmedGroupingNicknames: Set<String> = [
        "그레",
        "헤더"
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
        let resolvedMembersByNickname = Dictionary(
            uniqueKeysWithValues: resolvedMembers.map { ($0.member.nickname, $0) }
        )
        let trips = mockTrips
        // 리셋 전 시드에 이미 저장된 Google Place ID와 좌표를 재사용한다.
        // 기존 데이터에 없는 장소만 Google Places에 다시 요청한다.
        var existingPlaceCache = try await loadExistingPlaceCache(
            database: database,
            trips: trips
        )
        var resolvedPlacesByTripID: [String: [[[String: Any]]]] = [:]

        for trip in trips {
            resolvedPlacesByTripID[trip.id] = try await resolvePlaces(
                for: trip,
                existingPlaceCache: &existingPlaceCache
            )
        }

        let batch = database.batch()
        let allTripIDs = trips.map(\.id)
        let replacedTripIDs = Set(allTripIDs + obsoleteTripIDs)
        let expiresAt = Date().addingTimeInterval(72 * 60 * 60)

        for tripID in obsoleteTripIDs {
            batch.deleteDocument(database.collection("trips").document(tripID))
        }

        for trip in trips {
            let tripReference = database.collection("trips").document(trip.id)
            let inviteReference = database.collection("inviteCodes").document(trip.inviteCode)
            let tripMembers = try trip.memberNicknames.map { nickname in
                guard let member = resolvedMembersByNickname[nickname] else {
                    throw DevelopmentMockTripError.memberNotFound(nickname)
                }
                return member
            }

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
                    "developmentJoinedAvatarNames": tripMembers.map { $0.member.avatar.rawValue },
                    "developmentAllPlaceSelectionsConfirmed": tripMembers.allSatisfy {
                        preconfirmedPlaceSelectionNicknames.contains($0.member.nickname)
                    },
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

            let itineraryReference = tripReference.collection("itinerary").document("current")
            if let places = resolvedPlacesByTripID[trip.id],
               let itinerary = mockItinerary(
                   destination: trip.destination,
                   members: tripMembers,
                   resolvedPlaces: places
               ) {
                batch.setData(itinerary, forDocument: itineraryReference)
            } else {
                batch.deleteDocument(itineraryReference)
            }
        }

        for resolvedMember in resolvedMembers {
            let userReference = database.collection("users").document(resolvedMember.uid)
            let userDocument = try await userReference.getDocument()
            let existingJoined = userDocument.get("joinedTripIDs") as? [String] ?? []
            let existingDismissed = userDocument.get("dismissedTripIDs") as? [String] ?? []
            let memberTripIDs = trips
                .filter { $0.memberNicknames.contains(resolvedMember.member.nickname) }
                .map(\.id)
            let joined = Array(Set(existingJoined.filter { !replacedTripIDs.contains($0) } + memberTripIDs)).sorted()
            let dismissed = existingDismissed.filter { !replacedTripIDs.contains($0) }

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

    private static func resolvePlaces(
        for trip: Trip,
        existingPlaceCache: inout [String: [String: Any]]
    ) async throws -> [[[String: Any]]] {
        let placesService = GooglePlacesService()
        var result: [[[String: Any]]] = []

        for places in trip.memberPlaces {
            var memberPlaces: [[String: Any]] = []
            for place in places {
                let cacheKey = placeCacheKey(name: place.name, address: place.address)
                if let cached = existingPlaceCache[cacheKey] {
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
                    existingPlaceCache[cacheKey] = value
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

    private static func loadExistingPlaceCache(
        database: Firestore,
        trips: [Trip]
    ) async throws -> [String: [String: Any]] {
        var cache: [String: [String: Any]] = [:]
        var cachedDestinations: Set<String> = []
        let representativeTrips = trips.filter {
            cachedDestinations.insert($0.destination).inserted
        }
        for trip in representativeTrips {
            let participants = try await database
                .collection("trips")
                .document(trip.id)
                .collection("participants")
                .getDocuments()
            for participant in participants.documents {
                let places = participant.get("selectedPlaces") as? [[String: Any]] ?? []
                for place in places {
                    guard let name = place["name"] as? String,
                          let address = place["description"] as? String,
                          place["id"] as? String != nil,
                          place["latitude"] as? Double != nil,
                          place["longitude"] as? Double != nil
                    else { continue }
                    cache[placeCacheKey(name: name, address: address)] = place
                }
            }
        }
        return cache
    }

    private static func placeCacheKey(name: String, address: String) -> String {
        "\(name)|\(address)"
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

    private static func mockItinerary(
        destination: String,
        members: [ResolvedMember],
        resolvedPlaces: [[[String: Any]]]
    ) -> [String: Any]? {
        let seeds: (courses: [ItineraryCourseSeed], schedules: [ItineraryScheduleSeed])
        switch destination {
        case "도쿄":
            seeds = (
                courses: [
                    ItineraryCourseSeed(
                        id: 1_001,
                        title: "아사쿠사 시장·역사 코스",
                        placeNames: ["센소지", "나카미세 거리"],
                        memberIndexes: [0, 1, 2, 3],
                        durationMinutes: 120
                    ),
                    ItineraryCourseSeed(
                        id: 1_002,
                        title: "오다이바 게임·문화 코스",
                        placeNames: ["도쿄 조이폴리스", "일본과학미래관"],
                        memberIndexes: [0, 2],
                        durationMinutes: 120
                    ),
                    ItineraryCourseSeed(
                        id: 1_003,
                        title: "하라주쿠 쇼핑 코스",
                        placeNames: ["라포레 하라주쿠", "키디랜드 하라주쿠점"],
                        memberIndexes: [1, 3],
                        durationMinutes: 120
                    )
                ],
                schedules: [
                    ItineraryScheduleSeed(
                        id: 1_001,
                        courseID: 1_001,
                        startMinuteOfDay: 9 * 60,
                        branchGroupID: nil,
                        orderIndex: 0
                    ),
                    ItineraryScheduleSeed(
                        id: 1_002,
                        courseID: 1_002,
                        startMinuteOfDay: 12 * 60,
                        branchGroupID: 1,
                        orderIndex: 1
                    ),
                    ItineraryScheduleSeed(
                        id: 1_003,
                        courseID: 1_003,
                        startMinuteOfDay: 12 * 60,
                        branchGroupID: 1,
                        orderIndex: 2
                    )
                ]
            )

        case "상하이":
            seeds = (
                courses: [
                    ItineraryCourseSeed(
                        id: 2_001,
                        title: "와이탄 랜드마크·전망 코스",
                        placeNames: ["와이탄 전망대", "와이바이두 다리"],
                        memberIndexes: [0, 1, 2, 3],
                        durationMinutes: 120
                    ),
                    ItineraryCourseSeed(
                        id: 2_002,
                        title: "주자자오 역사·정원 코스",
                        placeNames: ["청대 우체국", "커즈위안"],
                        memberIndexes: [0, 2],
                        durationMinutes: 120
                    ),
                    ItineraryCourseSeed(
                        id: 2_003,
                        title: "디즈니 쇼핑·테마파크 코스",
                        placeNames: ["디즈니타운", "상하이 디즈니랜드"],
                        memberIndexes: [1, 3],
                        durationMinutes: 120
                    ),
                    ItineraryCourseSeed(
                        id: 2_004,
                        title: "팡성교 랜드마크 코스",
                        placeNames: ["팡성교"],
                        memberIndexes: [0, 2],
                        durationMinutes: 60
                    )
                ],
                schedules: [
                    ItineraryScheduleSeed(
                        id: 2_001,
                        courseID: 2_001,
                        startMinuteOfDay: 9 * 60,
                        branchGroupID: nil,
                        orderIndex: 0
                    ),
                    ItineraryScheduleSeed(
                        id: 2_002,
                        courseID: 2_002,
                        startMinuteOfDay: 12 * 60,
                        branchGroupID: 1,
                        orderIndex: 1
                    ),
                    ItineraryScheduleSeed(
                        id: 2_003,
                        courseID: 2_003,
                        startMinuteOfDay: 12 * 60,
                        branchGroupID: 1,
                        orderIndex: 2
                    ),
                    ItineraryScheduleSeed(
                        id: 2_004,
                        courseID: 2_004,
                        startMinuteOfDay: 16 * 60,
                        branchGroupID: nil,
                        orderIndex: 3
                    )
                ]
            )

        case "파리":
            seeds = (
                courses: [
                    ItineraryCourseSeed(
                        id: 3_001,
                        title: "마레 맛집·문화·자연 코스",
                        placeNames: ["라스 뒤 팔라펠", "보주 광장", "카르나발레 박물관"],
                        memberIndexes: [0, 1, 2, 3],
                        durationMinutes: 180
                    ),
                    ItineraryCourseSeed(
                        id: 3_002,
                        title: "불로뉴 문화·자연·테마파크 코스",
                        placeNames: ["아클리마타시옹 정원", "루이비통 재단 미술관", "바가텔 공원"],
                        memberIndexes: [0, 2],
                        durationMinutes: 180
                    ),
                    ItineraryCourseSeed(
                        id: 3_003,
                        title: "라 빌레트 공연·전시 코스",
                        placeNames: ["파리 필하모니", "과학산업관", "그랑드 알 드 라 빌레트", "라 제오드"],
                        memberIndexes: [1, 3],
                        durationMinutes: 180
                    )
                ],
                schedules: [
                    ItineraryScheduleSeed(
                        id: 3_001,
                        courseID: 3_001,
                        startMinuteOfDay: 9 * 60,
                        branchGroupID: nil,
                        orderIndex: 0
                    ),
                    ItineraryScheduleSeed(
                        id: 3_002,
                        courseID: 3_002,
                        startMinuteOfDay: 13 * 60,
                        branchGroupID: 1,
                        orderIndex: 1
                    ),
                    ItineraryScheduleSeed(
                        id: 3_003,
                        courseID: 3_003,
                        startMinuteOfDay: 13 * 60,
                        branchGroupID: 1,
                        orderIndex: 2
                    )
                ]
            )

        case "시드니":
            seeds = (
                courses: [
                    ItineraryCourseSeed(
                        id: 4_001,
                        title: "시드니 오페라하우스 코스",
                        placeNames: ["시드니 오페라하우스"],
                        memberIndexes: [0, 1, 2, 3],
                        durationMinutes: 60
                    ),
                    ItineraryCourseSeed(
                        id: 4_002,
                        title: "더 록스 시장·문화 코스",
                        placeNames: ["더 록스 마켓", "시드니 현대미술관"],
                        memberIndexes: [0, 1, 2, 3],
                        durationMinutes: 120
                    ),
                    ItineraryCourseSeed(
                        id: 4_003,
                        title: "맨리 문화·쇼핑·해변 코스",
                        placeNames: ["페어리 바워 풀", "맨리 코르소", "맨리 비치", "맨리 미술관·박물관", "셀리 비치"],
                        memberIndexes: [0, 2],
                        durationMinutes: 240
                    ),
                    ItineraryCourseSeed(
                        id: 4_004,
                        title: "패러매타 공연·문화·쇼핑 코스",
                        placeNames: ["패러매타 스퀘어", "웨스트필드 패러매타", "패러매타 리버사이드 시어터", "처치 스트리트 잇 스트리트", "패러매타 공원"],
                        memberIndexes: [1, 3],
                        durationMinutes: 240
                    )
                ],
                schedules: [
                    ItineraryScheduleSeed(
                        id: 4_001,
                        courseID: 4_001,
                        startMinuteOfDay: 9 * 60,
                        branchGroupID: nil,
                        orderIndex: 0
                    ),
                    ItineraryScheduleSeed(
                        id: 4_002,
                        courseID: 4_002,
                        startMinuteOfDay: 10 * 60 + 30,
                        branchGroupID: nil,
                        orderIndex: 1
                    ),
                    ItineraryScheduleSeed(
                        id: 4_003,
                        courseID: 4_003,
                        startMinuteOfDay: 13 * 60,
                        branchGroupID: 1,
                        orderIndex: 2
                    ),
                    ItineraryScheduleSeed(
                        id: 4_004,
                        courseID: 4_004,
                        startMinuteOfDay: 13 * 60,
                        branchGroupID: 1,
                        orderIndex: 3
                    )
                ]
            )

        default:
            return nil
        }

        let placesByName = resolvedPlaces
            .flatMap { $0 }
            .reduce(into: [String: [String: Any]]()) { result, place in
                guard let name = place["name"] as? String else { return }
                result[name] = place
            }

        let courseData: [[String: Any]] = seeds.courses.compactMap { course in
            let places = course.placeNames.compactMap { name -> [String: Any]? in
                guard let place = placesByName[name],
                      let latitude = place["latitude"] as? Double,
                      let longitude = place["longitude"] as? Double
                else { return nil }
                return [
                    "name": name,
                    "category": canonicalCategories[name] ?? place["category"] as? String ?? "",
                    "latitude": latitude,
                    "longitude": longitude
                ]
            }
            guard places.count == course.placeNames.count else { return nil }
            let memberIDs = course.memberIndexes.compactMap { index in
                members.indices.contains(index) ? members[index].member.avatar.rawValue : nil
            }
            return [
                "id": course.id,
                "title": course.title,
                "placeNames": course.placeNames,
                "categories": course.placeNames.compactMap { canonicalCategories[$0] },
                "memberIDs": memberIDs,
                "durationMinutes": course.durationMinutes,
                "places": places
            ]
        }
        guard courseData.count == seeds.courses.count else { return nil }

        let scheduleData: [[String: Any]] = seeds.schedules.map { schedule in
            var data: [String: Any] = [
                "id": schedule.id,
                "courseID": schedule.courseID,
                "day": "DAY 1",
                "startMinuteOfDay": schedule.startMinuteOfDay,
                "orderIndex": schedule.orderIndex
            ]
            if let branchGroupID = schedule.branchGroupID {
                data["branchGroupID"] = branchGroupID
            }
            return data
        }

        return [
            "courses": courseData,
            "schedules": scheduleData,
            "recommendations": [],
            "updatedBy": "development-seed",
            "updatedAt": FieldValue.serverTimestamp()
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
    private static let obsoleteTripIDs = [
        "dev-seed-trip-tokyo-hardin-seni",
        "dev-seed-trip-shanghai-hardin-seni",
        "dev-seed-trip-new-york-hardin-seni",
        "dev-seed-trip-paris-hardin-seni",
        "dev-seed-trip-sydney-hardin-seni",
        "dev-seed-trip-vancouver-hardin-seni"
    ]

    private static var mockTrips: [Trip] {
        [tokyo, shanghai, newYork, paris, sydney, vancouver]
            .flatMap(pairedTrips)
    }

    private static let primaryRoomMembers = ["테이", "하르딘", "그레", "헤더"]

    nonisolated private static func pairedTrips(_ trip: Trip) -> [Trip] {
        let roomPlaces: [[Place]]
        switch trip.memberPlaces.count {
        case 4...:
            roomPlaces = Array(trip.memberPlaces.prefix(4))
        case 3:
            roomPlaces = trip.memberPlaces + [trip.memberPlaces[2]]
        case 2:
            roomPlaces = [
                trip.memberPlaces[0],
                trip.memberPlaces[1],
                trip.memberPlaces[0],
                trip.memberPlaces[1]
            ]
        default:
            roomPlaces = trip.memberPlaces
        }
        let primaryTrip = Trip(
            id: trip.id,
            inviteCode: trip.inviteCode,
            title: trip.title,
            country: trip.country,
            destination: trip.destination,
            startDate: trip.startDate,
            endDate: trip.endDate,
            transportation: trip.transportation,
            maximumTravelMinutes: trip.maximumTravelMinutes,
            memberNicknames: trip.memberNicknames,
            memberPlaces: roomPlaces
        )
        let secondaryInviteCode = String((Int(trip.inviteCode) ?? 0) + 1)
        let secondaryTrip = Trip(
            id: "\(trip.id)-juni-seni",
            inviteCode: secondaryInviteCode,
            title: trip.title,
            country: trip.country,
            destination: trip.destination,
            startDate: trip.startDate,
            endDate: trip.endDate,
            transportation: trip.transportation,
            maximumTravelMinutes: trip.maximumTravelMinutes,
            memberNicknames: ["주니", "세니", "그레", "헤더"],
            memberPlaces: roomPlaces
        )
        return [primaryTrip, secondaryTrip]
    }

    private static func places(_ values: [(String, String, String)]) -> [Place] {
        values.map {
            Place(
                name: $0.0,
                category: canonicalCategories[$0.0] ?? $0.1,
                address: canonicalAddresses[$0.0] ?? $0.2
            )
        }
    }

    private static let canonicalCategories: [String: String] = [
        "센소지": "역사·종교", "나카미세 거리": "시장",
        "라포레 하라주쿠": "쇼핑", "키디랜드 하라주쿠점": "기념품",
        "일본과학미래관": "박물관", "도쿄 조이폴리스": "게임·오락",
        "와이탄 전망대": "전망대", "와이바이두 다리": "랜드마크",
        "커즈위안": "공원·정원", "팡성교": "랜드마크",
        "청대 우체국": "역사·종교", "상하이 디즈니랜드": "테마파크",
        "디즈니타운": "쇼핑", "월드 오브 디즈니 스토어": "기념품",
        "위싱 스타 파크": "공원·정원",
        "메트 클로이스터스": "미술관", "포트 트라이언 공원": "공원·정원",
        "다이크먼 팜하우스 박물관": "박물관", "인우드 힐 공원": "공원·정원",
        "유나이티드 팰리스": "공연·전시", "포트 워싱턴 퍼블릭 하우스": "맛집",
        "뉴욕 아쿠아리움": "동물원·수족관", "코니아일랜드 보드워크": "해변",
        "패러슈트 점프": "랜드마크", "코니아일랜드 박물관": "박물관",
        "루나 파크": "테마파크", "네이선스 페이머스 본점": "맛집",
        "카르나발레 박물관": "박물관", "보주 광장": "공원·정원",
        "라스 뒤 팔라펠": "맛집", "루이비통 재단 미술관": "미술관",
        "아클리마타시옹 정원": "테마파크", "바가텔 공원": "공원·정원",
        "프레 카틀랑 정원": "공원·정원", "샬레 데 질": "맛집",
        "오퇴유 온실 정원": "공원·정원", "과학산업관": "박물관",
        "라 제오드": "게임·오락", "파리 필하모니": "공연·전시",
        "그랑드 알 드 라 빌레트": "공연·전시", "빌레트 공원": "공원·정원",
        "붐붐 빌레트 푸드홀": "맛집",
        "시드니 오페라하우스": "랜드마크", "시드니 현대미술관": "미술관",
        "더 록스 마켓": "시장", "맨리 비치": "해변", "셸리 비치": "해변",
        "맨리 미술관·박물관": "미술관", "페어리 바워 풀": "관광지",
        "맨리 코르소": "쇼핑", "웨스트필드 패러매타": "쇼핑",
        "패러매타 스퀘어": "관광지", "처치 스트리트 잇 스트리트": "맛집",
        "패러매타 리버사이드 시어터": "공연·전시", "패러매타 공원": "공원·정원",
        "그랜빌 아일랜드 퍼블릭 마켓": "시장", "넷 로프트": "편집숍",
        "UBC 인류학박물관": "박물관", "니토베 기념정원": "공원·정원",
        "비티 생물다양성 박물관": "박물관", "론즈데일 키 마켓": "시장",
        "폴리곤 갤러리": "미술관", "쉽야즈": "관광지",
        "스티브스턴 피셔맨스 워프": "시장", "걸프 오브 조지아 캐너리": "박물관",
        "브리타니아 조선소": "역사·종교"
    ]

    private static let canonicalAddresses: [String: String] = [
        "센소지": "〒111-0032 東京都台東区浅草2丁目3-1",
        "나카미세 거리": "〒111-0032 東京都台東区浅草1丁目36-3",
        "라포레 하라주쿠": "〒150-0001 東京都渋谷区神宮前1丁目11-6",
        "키디랜드 하라주쿠점": "〒150-0001 東京都渋谷区神宮前6丁目1-9",
        "일본과학미래관": "〒135-0064 東京都江東区青海2丁目3-6",
        "도쿄 조이폴리스": "〒135-0091 東京都港区台場1丁目6-1 デックス東京ビーチ 3–5F",
        "와이탄 전망대": "中国上海市黄浦区中山东一路 강변, 南京东路 교차점 맞은편",
        "와이바이두 다리": "中国上海市黄浦区中山东一路 북쪽 끝, 苏州河 하구",
        "커즈위안": "中国上海市青浦区朱家角镇西井街111号",
        "팡성교": "中国上海市青浦区朱家角镇北大街东首",
        "청대 우체국": "中国上海市青浦区朱家角镇西湖街35号",
        "상하이 디즈니랜드": "中国上海市浦东新区川沙镇黄赵路310号 · 上海迪士尼乐园",
        "디즈니타운": "中国上海市浦东新区川沙镇黄赵路310号 · 迪士尼小镇",
        "월드 오브 디즈니 스토어": "中国上海市浦东新区川沙镇黄赵路310号 · 迪士尼小镇内迪士尼世界商店",
        "위싱 스타 파크": "中国上海市浦东新区川沙镇黄赵路310号 · 星愿公园",
        "메트 클로이스터스": "99 Margaret Corbin Dr, New York, NY 10040, USA",
        "포트 트라이언 공원": "Margaret Corbin Circle, Fort Washington Ave & Cabrini Blvd, New York, NY 10040, USA",
        "다이크먼 팜하우스 박물관": "4881 Broadway, New York, NY 10034, USA",
        "인우드 힐 공원": "Payson Ave & Dyckman St, New York, NY 10034, USA",
        "유나이티드 팰리스": "4140 Broadway, New York, NY 10033, USA",
        "포트 워싱턴 퍼블릭 하우스": "3938 Broadway, New York, NY 10032, USA",
        "뉴욕 아쿠아리움": "602 Surf Ave, Brooklyn, NY 11224, USA",
        "코니아일랜드 보드워크": "Stillwell Ave & Riegelmann Boardwalk, Brooklyn, NY 11224, USA",
        "패러슈트 점프": "Riegelmann Boardwalk & W 16th St, Brooklyn, NY 11224, USA",
        "코니아일랜드 박물관": "1208 Surf Ave, Brooklyn, NY 11224, USA",
        "루나 파크": "1000 Surf Ave, Brooklyn, NY 11224, USA",
        "네이선스 페이머스 본점": "1310 Surf Ave, Brooklyn, NY 11224, USA",
        "카르나발레 박물관": "23 Rue de Sévigné, 75003 Paris, France",
        "보주 광장": "Place des Vosges, 75004 Paris, France",
        "라스 뒤 팔라펠": "34 Rue des Rosiers, 75004 Paris, France",
        "루이비통 재단 미술관": "8 Avenue du Mahatma Gandhi, 75116 Paris, France",
        "아클리마타시옹 정원": "Bois de Boulogne, 75116 Paris, France",
        "바가텔 공원": "Route de Sèvres à Neuilly, Bois de Boulogne, 75016 Paris, France",
        "프레 카틀랑 정원": "Route de Suresnes, Bois de Boulogne, 75016 Paris, France",
        "샬레 데 질": "14 Chemin de Ceinture du Lac Inférieur, Bois de Boulogne, 75016 Paris, France",
        "오퇴유 온실 정원": "1 Avenue Gordon Bennett, 75016 Paris, France",
        "과학산업관": "30 Avenue Corentin Cariou, 75019 Paris, France",
        "라 제오드": "26 Avenue Corentin Cariou, 75019 Paris, France",
        "파리 필하모니": "221 Avenue Jean-Jaurès, 75019 Paris, France",
        "그랑드 알 드 라 빌레트": "211 Avenue Jean-Jaurès, 75019 Paris, France",
        "빌레트 공원": "211 Avenue Jean-Jaurès, 75019 Paris, France",
        "붐붐 빌레트 푸드홀": "30 Avenue Corentin Cariou, 75019 Paris, France",
        "시드니 오페라하우스": "Bennelong Point, Sydney NSW 2000, Australia",
        "시드니 현대미술관": "140 George St, The Rocks NSW 2000, Australia",
        "더 록스 마켓": "George St & Playfair St, The Rocks NSW 2000, Australia",
        "맨리 비치": "North Steyne & The Corso, Manly NSW 2095, Australia",
        "셸리 비치": "Bower St, Manly NSW 2095, Australia",
        "맨리 미술관·박물관": "West Esplanade Reserve, Manly NSW 2095, Australia",
        "페어리 바워 풀": "Marine Parade, Manly NSW 2095, Australia",
        "맨리 코르소": "The Corso & Darley Rd, Manly NSW 2095, Australia",
        "웨스트필드 패러매타": "159–175 Church St, Parramatta NSW 2150, Australia",
        "패러매타 스퀘어": "5 Parramatta Square, Parramatta NSW 2150, Australia",
        "처치 스트리트 잇 스트리트": "Church St & Phillip St, Parramatta NSW 2150, Australia",
        "패러매타 리버사이드 시어터": "Church St & Market St, Parramatta NSW 2150, Australia",
        "패러매타 공원": "Macquarie St & Pitt St, Parramatta NSW 2150, Australia",
        "그랜빌 아일랜드 퍼블릭 마켓": "1689 Johnston St, Vancouver, BC V6H 3R9, Canada",
        "넷 로프트": "1666 Johnston St, Vancouver, BC V6H 3S2, Canada",
        "UBC 인류학박물관": "6393 NW Marine Dr, Vancouver, BC V6T 1Z2, Canada",
        "니토베 기념정원": "1895 Lower Mall, Vancouver, BC V6T 1Z4, Canada",
        "비티 생물다양성 박물관": "2212 Main Mall, Vancouver, BC V6T 1Z4, Canada",
        "론즈데일 키 마켓": "123 Carrie Cates Ct, North Vancouver, BC V7M 3K7, Canada",
        "폴리곤 갤러리": "101 Carrie Cates Ct, North Vancouver, BC V7M 3J4, Canada",
        "쉽야즈": "125 Victory Ship Way, North Vancouver, BC V7L 0B3, Canada",
        "스티브스턴 피셔맨스 워프": "3800 Bayview St, Richmond, BC V7E 4R7, Canada",
        "걸프 오브 조지아 캐너리": "12138 Fourth Ave, Richmond, BC V7E 3J1, Canada",
        "브리타니아 조선소": "5180 Westwater Dr, Richmond, BC V7E 6P3, Canada"
    ]

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
        memberNicknames: primaryRoomMembers,
        memberPlaces: [
            places([
                ("센소지", "역사·종교", "〒111-0032 東京都台東区浅草2丁目3-1"),
                ("나카미세 거리", "시장", "〒111-0032 東京都台東区浅草1丁目36-3"),
                ("일본과학미래관", "박물관", "〒135-0064 東京都江東区青海2丁目3-6"),
                ("도쿄 조이폴리스", "게임·오락", "〒135-0091 東京都港区台場1丁目6-1 デックス東京ビーチ 3–5F")
            ]),
            places([
                ("센소지", "역사·종교", "〒111-0032 東京都台東区浅草2丁目3-1"),
                ("나카미세 거리", "시장", "〒111-0032 東京都台東区浅草1丁目36-3"),
                ("라포레 하라주쿠", "쇼핑", "〒150-0001 東京都渋谷区神宮前1丁目11-6"),
                ("키디랜드 하라주쿠점", "기념품", "〒150-0001 東京都渋谷区神宮前6丁目1-9")
            ]),
            places([
                ("센소지", "역사·종교", "〒111-0032 東京都台東区浅草2丁目3-1"),
                ("나카미세 거리", "시장", "〒111-0032 東京都台東区浅草1丁目36-3"),
                ("일본과학미래관", "박물관", "〒135-0064 東京都江東区青海2丁目3-6"),
                ("도쿄 조이폴리스", "게임·오락", "〒135-0091 東京都港区台場1丁目6-1 デックス東京ビーチ 3–5F")
            ]),
            places([
                ("센소지", "역사·종교", "〒111-0032 東京都台東区浅草2丁目3-1"),
                ("나카미세 거리", "시장", "〒111-0032 東京都台東区浅草1丁目36-3"),
                ("라포레 하라주쿠", "쇼핑", "〒150-0001 東京都渋谷区神宮前1丁目11-6"),
                ("키디랜드 하라주쿠점", "기념품", "〒150-0001 東京都渋谷区神宮前6丁目1-9")
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
        memberNicknames: primaryRoomMembers,
        memberPlaces: [
            places([
                ("와이탄 전망대", "전망", "The Bund Viewing Platform Shanghai"),
                ("와이바이두 다리", "건축", "Waibaidu Bridge Shanghai"),
                ("커즈위안", "공원·정원", "Kezhi Garden Zhujiajiao Shanghai"),
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
                ("커즈위안", "공원·정원", "Kezhi Garden Zhujiajiao Shanghai"),
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
        memberNicknames: primaryRoomMembers,
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
        memberNicknames: primaryRoomMembers,
        memberPlaces: [
            places([
                ("카르나발레 박물관", "박물관", "Musee Carnavalet Paris"),
                ("보주 광장", "산책", "Place des Vosges Paris"),
                ("라스 뒤 팔라펠", "맛집", "L'As du Fallafel Paris"),
                ("루이비통 재단 미술관", "현대미술", "Fondation Louis Vuitton Paris"),
                ("아클리마타시옹 정원", "놀이공원", "Jardin d'Acclimatation Paris"),
                ("바가텔 공원", "정원", "Parc de Bagatelle Paris"),
                ("프레 카틀랑 정원", "산책", "Jardin du Pre Catelan Paris"),
                ("샬레 데 질", "호숫가 식사", "Le Chalet des Iles Bois de Boulogne Paris")
            ]),
            places([
                ("카르나발레 박물관", "박물관", "Musee Carnavalet Paris"),
                ("보주 광장", "산책", "Place des Vosges Paris"),
                ("라스 뒤 팔라펠", "맛집", "L'As du Fallafel Paris"),
                ("과학산업관", "과학 체험", "Cite des sciences et de l'industrie Paris"),
                ("라 제오드", "영화·건축", "La Geode Paris"),
                ("파리 필하모니", "공연", "Philharmonie de Paris"),
                ("그랑드 알 드 라 빌레트", "전시", "Grande Halle de la Villette Paris"),
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
                ("샬레 데 질", "호숫가 식사", "Le Chalet des Iles Bois de Boulogne Paris")
            ]),
            places([
                ("카르나발레 박물관", "박물관", "Musee Carnavalet Paris"),
                ("보주 광장", "산책", "Place des Vosges Paris"),
                ("라스 뒤 팔라펠", "맛집", "L'As du Fallafel Paris"),
                ("과학산업관", "과학 체험", "Cite des sciences et de l'industrie Paris"),
                ("라 제오드", "영화·건축", "La Geode Paris"),
                ("파리 필하모니", "공연", "Philharmonie de Paris"),
                ("그랑드 알 드 라 빌레트", "전시", "Grande Halle de la Villette Paris"),
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
        memberNicknames: primaryRoomMembers,
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
        memberNicknames: primaryRoomMembers,
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

