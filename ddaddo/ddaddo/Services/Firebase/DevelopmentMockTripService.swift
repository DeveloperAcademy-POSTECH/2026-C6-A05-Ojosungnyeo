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
            nickname: "데브주니",
            nicknameKey: "c9dd15f227d8e64d2c71f96da03a19dc95054c7910986696a212a10f60f47a75",
            avatar: .juni
        ),
        Member(
            nickname: "데브짭주니",
            nicknameKey: "a7d1dce39fac951b2b82a3a31b33530b1e6f238c5accecc45d1a1b2fde25418d",
            avatar: .grae
        ),
        Member(
            nickname: "한테이",
            nicknameKey: "7646cd9a72f31acbe7c2b25674f4bcda614d89d002727194ceae4fe18027e257",
            avatar: .tae
        ),
        Member(
            nickname: "흑르딩",
            nicknameKey: "fe434f9eaba3fe1f6c20b87c550d10202f772ff4b49513dae4ed05e3bbe87e98",
            avatar: .header
        )
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

        let batch = database.batch()
        let allTripIDs = trips.map(\.id)
        let expiresAt = makeDate(year: 2030, month: 12, day: 31)

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
                batch.setData(
                    [
                        "slotIndex": index,
                        "uid": resolvedMember.uid,
                        "name": resolvedMember.member.nickname,
                        "avatarName": resolvedMember.member.avatar.rawValue,
                        "role": index == 0 ? "owner" : "member",
                        "status": "joined",
                        "selectedPlaces": places,
                        "placeSelectionConfirmed": true,
                        "groupingConfirmed": false,
                        "confirmedGroupIDs": [],
                        "joinedGroupIDs": [],
                        "joinedAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
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

                let value = try await resolvePlace(
                    place,
                    destination: trip.destination,
                    placesService: placesService
                )
                cache[cacheKey] = value
                memberPlaces.append(value)
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
                ("센소지", "문화", "2 Chome-3-1 Asakusa, Taito City, Tokyo"),
                ("갓파바시 도구거리", "쇼핑", "3 Chome-18-2 Matsugaya, Taito City, Tokyo"),
                ("기요스미 정원", "자연", "3 Chome-3-9 Kiyosumi, Koto City, Tokyo"),
                ("시부야 스카이", "전망", "Shibuya Scramble Square, Tokyo")
            ]),
            places([
                ("닌텐도 도쿄", "쇼핑", "Shibuya PARCO 6F, Tokyo"),
                ("포켓몬센터 시부야", "쇼핑", "Shibuya PARCO 6F, Tokyo"),
                ("지브리 미술관", "문화", "1 Chome-1-83 Shimorenjaku, Mitaka, Tokyo"),
                ("나카노 브로드웨이", "쇼핑", "5 Chome-52-15 Nakano, Tokyo")
            ]),
            places([
                ("네즈 미술관", "문화", "6 Chome-5-1 Minamiaoyama, Minato City, Tokyo"),
                ("오모테산도", "쇼핑", "Omotesando Hills, Tokyo"),
                ("21_21 디자인 사이트", "문화", "Tokyo Midtown Garden, Akasaka, Tokyo"),
                ("다이칸야마 T-SITE", "카페·서점", "16-15 Sarugakucho, Shibuya, Tokyo")
            ]),
            places([
                ("츠키지 장외시장", "맛집", "4 Chome Tsukiji, Chuo City, Tokyo"),
                ("센소지", "문화", "2 Chome-3-1 Asakusa, Taito City, Tokyo"),
                ("아메요코 시장", "맛집·쇼핑", "6 Chome-10-7 Ueno, Taito City, Tokyo"),
                ("하모니카 요코초", "맛집", "1 Chome-1-3 Kichijoji Honcho, Tokyo")
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
        maximumTravelMinutes: 15,
        memberPlaces: [
            places([
                ("상하이박물관", "문화", "201 Renmin Avenue, Shanghai"), ("예원", "문화", "168 Fuyou Road, Shanghai"),
                ("와이탄", "관광지", "Zhongshan East 1st Road, Shanghai"), ("푸싱공원", "자연", "516 Fuxing Middle Road, Shanghai"),
                ("록번드 미술관", "문화", "20 Huqiu Road, Shanghai"), ("상하이타워", "전망", "501 Yincheng Middle Road, Shanghai")
            ]),
            places([
                ("난징동루", "쇼핑", "Nanjing East Road, Shanghai"), ("신천지", "쇼핑", "245 Madang Road, Shanghai"),
                ("톈즈팡", "쇼핑", "Lane 210, Taikang Road, Shanghai"), ("상하이 IFC몰", "쇼핑", "8 Century Avenue, Shanghai"),
                ("예원상성", "쇼핑", "265 Fangbang Middle Road, Shanghai"), ("우캉루", "관광지", "Wukang Road, Shanghai")
            ]),
            places([
                ("상하이박물관", "문화", "201 Renmin Avenue, Shanghai"), ("록번드 미술관", "문화", "20 Huqiu Road, Shanghai"),
                ("파워스테이션 오브 아트", "문화", "678 Miaojiang Road, Shanghai"), ("서안미술관", "문화", "2600 Longteng Avenue, Shanghai"),
                ("M50 창의원", "문화", "50 Moganshan Road, Shanghai"), ("우캉루", "관광지", "Wukang Road, Shanghai")
            ]),
            places([
                ("예원상성", "맛집", "265 Fangbang Middle Road, Shanghai"), ("황허루", "맛집", "Huanghe Road, Shanghai"),
                ("윈난난루 미식거리", "맛집", "Yunnan South Road, Shanghai"), ("톈즈팡", "카페", "Lane 210, Taikang Road, Shanghai"),
                ("난징동루", "쇼핑", "Nanjing East Road, Shanghai"), ("신천지", "맛집", "245 Madang Road, Shanghai")
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
        maximumTravelMinutes: 60,
        memberPlaces: [
            places([
                ("메트로폴리탄 미술관", "문화", "1000 5th Ave, New York, NY"), ("뉴욕 공립도서관", "문화", "476 5th Ave, New York, NY"),
                ("센트럴 파크", "자연", "Central Park, New York, NY"), ("탑 오브 더 록", "전망", "30 Rockefeller Plaza, New York, NY"),
                ("MoMA", "문화", "11 W 53rd St, New York, NY"), ("휘트니 미술관", "문화", "99 Gansevoort St, New York, NY"),
                ("모건 라이브러리", "문화", "225 Madison Ave, New York, NY"), ("하이라인", "건축·자연", "91 Gansevoort St, New York, NY")
            ]),
            places([
                ("닌텐도 뉴욕", "쇼핑", "10 Rockefeller Plaza, New York, NY"), ("소호", "쇼핑", "Broadway & Prince St, New York, NY"),
                ("5번가", "쇼핑", "5th Ave & W 50th St, New York, NY"), ("허드슨 야드", "쇼핑", "20 Hudson Yards, New York, NY"),
                ("첼시 마켓", "맛집", "75 9th Ave, New York, NY"), ("에식스 마켓", "맛집", "88 Essex St, New York, NY"),
                ("카츠 델리카트슨", "맛집", "205 E Houston St, New York, NY"), ("타임아웃 마켓", "맛집", "55 Water St, Brooklyn, NY")
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
        maximumTravelMinutes: 60,
        memberPlaces: [
            places([
                ("루브르박물관", "문화", "Rue de Rivoli, Paris"), ("생트샤펠", "문화", "10 Boulevard du Palais, Paris"),
                ("오르세 미술관", "문화", "Esplanade Valéry Giscard d’Estaing, Paris"), ("뤽상부르공원", "자연", "Rue de Médicis, Paris"),
                ("튈르리 정원", "자연", "Place de la Concorde, Paris"), ("로댕 미술관", "문화", "77 Rue de Varenne, Paris"),
                ("오페라 가르니에", "문화", "Place de l’Opéra, Paris"), ("개선문", "관광지", "Place Charles de Gaulle, Paris"),
                ("에펠탑", "전망", "5 Avenue Anatole France, Paris")
            ]),
            places([
                ("마레 지구", "쇼핑", "Place des Vosges, Paris"), ("사마리텐 백화점", "쇼핑", "9 Rue de la Monnaie, Paris"),
                ("갤러리 라파예트 오스만", "쇼핑", "40 Boulevard Haussmann, Paris"), ("프랭탕 오스만", "쇼핑", "64 Boulevard Haussmann, Paris"),
                ("생투앙 벼룩시장", "쇼핑", "110 Rue des Rosiers, Saint-Ouen-sur-Seine"), ("르 봉 마르셰", "쇼핑", "24 Rue de Sèvres, Paris"),
                ("팔레 루아얄", "관광지", "8 Rue de Montpensier, Paris"), ("몽토르게이 거리", "맛집", "Rue Montorgueil, Paris"),
                ("샹젤리제 거리", "쇼핑", "Avenue des Champs-Élysées, Paris")
            ]),
            places([
                ("루브르박물관", "문화", "Rue de Rivoli, Paris"), ("오르세 미술관", "문화", "Esplanade Valéry Giscard d’Estaing, Paris"),
                ("오랑주리 미술관", "문화", "Jardin des Tuileries, Paris"), ("루이비통 재단 미술관", "문화", "8 Avenue du Mahatma Gandhi, Paris"),
                ("피카소 미술관", "문화", "5 Rue de Thorigny, Paris"), ("부르스 드 코메르스", "문화", "2 Rue de Viarmes, Paris"),
                ("팔레 드 도쿄", "문화", "13 Avenue du Président Wilson, Paris"), ("카르나발레 박물관", "문화", "23 Rue de Sévigné, Paris"),
                ("메르시", "쇼핑", "111 Boulevard Beaumarchais, Paris")
            ]),
            places([
                ("마레 지구", "맛집", "Place des Vosges, Paris"), ("앙팡루주 시장", "맛집", "39 Rue de Bretagne, Paris"),
                ("몽토르게이 거리", "맛집", "Rue Montorgueil, Paris"), ("생제르맹 카페거리", "카페", "Boulevard Saint-Germain, Paris"),
                ("생마르탱 운하", "카페", "Quai de Valmy, Paris"), ("바스티유 시장", "맛집", "Boulevard Richard-Lenoir, Paris"),
                ("무프타르 거리", "맛집", "Rue Mouffetard, Paris"), ("클레르 거리", "맛집", "Rue Cler, Paris"),
                ("몽마르트르 아베스 거리", "카페", "Rue des Abbesses, Paris")
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
        transportation: Transportation.car.rawValue,
        maximumTravelMinutes: 30,
        memberPlaces: [
            places([
                ("시드니 오페라하우스", "문화", "Bennelong Point, Sydney NSW"), ("로열 보타닉 가든", "자연", "Mrs Macquaries Road, Sydney NSW"),
                ("NSW 주립미술관", "문화", "Art Gallery Road, Sydney NSW"), ("미세스 맥쿼리스 포인트", "전망", "1d Mrs Macquaries Road, Sydney NSW"),
                ("본다이 비치", "자연", "Queen Elizabeth Drive, Bondi Beach NSW"), ("맨리 비치", "자연", "North Steyne, Manly NSW"),
                ("시드니 현대미술관", "문화", "140 George Street, The Rocks NSW"), ("NSW 주립도서관", "문화", "1 Shakespeare Place, Sydney NSW")
            ]),
            places([
                ("퀸 빅토리아 빌딩", "쇼핑", "455 George Street, Sydney NSW"), ("패딩턴 마켓", "쇼핑", "395 Oxford Street, Paddington NSW"),
                ("더 갤러리즈", "쇼핑", "500 George Street, Sydney NSW"), ("뉴타운 킹 스트리트", "쇼핑", "King Street, Newtown NSW"),
                ("더 록스 마켓", "쇼핑", "George Street, The Rocks NSW"), ("맨리 코르소", "쇼핑", "The Corso, Manly NSW"),
                ("본다이 정션", "쇼핑", "500 Oxford Street, Bondi Junction NSW"), ("더 그라운즈 오브 알렉산드리아", "카페", "7a/2 Huntley Street, Alexandria NSW")
            ]),
            places([
                ("시드니 현대미술관", "문화", "140 George Street, The Rocks NSW"), ("화이트 래빗 갤러리", "문화", "30 Balfour Street, Chippendale NSW"),
                ("캐리지웍스", "문화", "245 Wilson Street, Eveleigh NSW"), ("NSW 주립도서관", "문화", "1 Shakespeare Place, Sydney NSW"),
                ("NSW 주립미술관", "문화", "Art Gallery Road, Sydney NSW"), ("시드니 오페라하우스", "문화", "Bennelong Point, Sydney NSW"),
                ("차우착윙 박물관", "문화", "University Place, Camperdown NSW"), ("파워하우스 뮤지엄", "문화", "500 Harris Street, Ultimo NSW")
            ]),
            places([
                ("시드니 피시마켓", "맛집", "Pyrmont Bridge Road and Bank Street, Sydney NSW"), ("더 그라운즈 오브 알렉산드리아", "카페", "7a/2 Huntley Street, Alexandria NSW"),
                ("스파이스 앨리", "맛집", "Kensington Street, Chippendale NSW"), ("맨리 워프", "맛집", "Belgrave Street, Manly NSW"),
                ("더 록스 마켓", "맛집", "George Street, The Rocks NSW"), ("뉴타운 킹 스트리트", "맛집", "King Street, Newtown NSW"),
                ("본다이 파머스 마켓", "맛집", "2–4 Wellington Street, Bondi NSW")
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
                ("밴쿠버 공립도서관 중앙관", "문화", "350 West Georgia Street, Vancouver, BC, Canada"),
                ("그랜빌 아일랜드 퍼블릭 마켓", "맛집", "1689 Johnston Street, Vancouver, BC, Canada"),
                ("UBC 캠퍼스 메인 몰", "산책", "Main Mall, University of British Columbia, Vancouver, BC, Canada"),
                ("UBC 인류학박물관", "문화", "6393 NW Marine Drive, Vancouver, BC, Canada"),
                ("스탠리 파크", "자연", "Stanley Park, Vancouver, BC, Canada"),
                ("잉글리시 베이 비치", "자연", "Beach Avenue & Denman Street, Vancouver, BC, Canada"),
                ("캐나다 플레이스", "전망", "999 Canada Place, Vancouver, BC, Canada"),
                ("쉽야즈 크리스마스 마켓", "축제", "125 Victory Ship Way, North Vancouver, BC, Canada")
            ]),
            places([
                ("밴쿠버 공립도서관 중앙관", "문화", "350 West Georgia Street, Vancouver, BC, Canada"),
                ("그랜빌 아일랜드 퍼블릭 마켓", "맛집", "1689 Johnston Street, Vancouver, BC, Canada"),
                ("넷 로프트", "쇼핑", "1666 Johnston Street, Vancouver, BC, Canada"),
                ("롭슨 스트리트", "쇼핑", "Robson Street, Vancouver, BC, Canada"),
                ("UBC 북스토어", "쇼핑", "6200 University Boulevard, Vancouver, BC, Canada"),
                ("개스타운 워터 스트리트", "쇼핑", "Water Street, Vancouver, BC, Canada"),
                ("론즈데일 키 마켓", "맛집", "123 Carrie Cates Court, North Vancouver, BC, Canada"),
                ("쉽야즈 크리스마스 마켓", "축제", "125 Victory Ship Way, North Vancouver, BC, Canada")
            ]),
            places([
                ("밴쿠버 공립도서관 중앙관", "문화", "350 West Georgia Street, Vancouver, BC, Canada"),
                ("그랜빌 아일랜드 퍼블릭 마켓", "맛집", "1689 Johnston Street, Vancouver, BC, Canada"),
                ("UBC 인류학박물관", "문화", "6393 NW Marine Drive, Vancouver, BC, Canada"),
                ("스탠리 파크", "자연", "Stanley Park, Vancouver, BC, Canada"),
                ("개스타운 증기시계", "관광", "305 Water Street, Vancouver, BC, Canada"),
                ("개스타운 워터 스트리트", "쇼핑", "Water Street, Vancouver, BC, Canada"),
                ("론즈데일 키 마켓", "맛집", "123 Carrie Cates Court, North Vancouver, BC, Canada"),
                ("쉽야즈 크리스마스 마켓", "축제", "125 Victory Ship Way, North Vancouver, BC, Canada")
            ])
        ]
    )
}
#endif

