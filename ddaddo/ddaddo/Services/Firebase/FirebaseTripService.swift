//
//  FirebaseTripService.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirebaseTripService {
    private static let inviteURLBase = "https://ddaddo-web.vercel.app/invite"
    private static let inviteDuration: TimeInterval = 72 * 60 * 60
    private static let developmentInviteDuration: TimeInterval = 60
    private static let developmentInviteCodes = Set(["123456", "987654", "111111"])
    private static let developmentTripIDs = Set(
        developmentInviteCodes.map { "development-trip-\($0)" }
    )
    private static let duplicateCodeDomain = "FirebaseTripService.DuplicateInviteCode"

    static func createTrip(_ request: TripCreationRequest) async throws -> TripInvitationSnapshot {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }
        guard let userID = Auth.auth().currentUser?.uid else {
            throw TripServiceError.unauthenticated
        }

        let database = Firestore.firestore()
        let userDocument = try await database.collection("users").document(userID).getDocument()
        let nickname = (userDocument.get("nickname") as? String) ?? "나"
        let storedAvatar = (userDocument.get("avatarName") as? String)
            .flatMap { ParticipantAvatar(rawValue: $0) }
        let ownerAvatar = ParticipantAvatar.matched(to: nickname)
            ?? storedAvatar
            ?? ParticipantAvatar.allCases.randomElement()!
        let participantAvatars = ParticipantAvatar.uniqueAssignments(
            count: request.travelerCount,
            first: ownerAvatar
        )

        for _ in 0..<5 {
            let tripReference = database.collection("trips").document()
            let inviteCode = String(format: "%06d", Int.random(in: 0...999_999))
            let inviteReference = database.collection("inviteCodes").document(inviteCode)
            let expiresAt = Date().addingTimeInterval(inviteDuration)
            let inviteURL = makeInviteURL(code: inviteCode, expiresAt: expiresAt)

            do {
                _ = try await database.runTransaction { transaction, errorPointer in
                    do {
                        let inviteDocument = try transaction.getDocument(inviteReference)
                        guard !inviteDocument.exists else {
                            errorPointer?.pointee = NSError(domain: duplicateCodeDomain, code: 409)
                            return nil
                        }

                        transaction.setData(
                            [
                                "ownerID": userID,
                                "title": request.title,
                                "destinationIDs": request.destinations.map(\.id),
                                "destinations": request.destinations.map {
                                    ["id": $0.id, "country": $0.country, "name": $0.name]
                                },
                                "startAt": Timestamp(date: request.startDate),
                                "endAt": Timestamp(date: request.endDate),
                                "travelerCount": request.travelerCount,
                                "transportation": request.transportation,
                                "maximumTravelMinutes": request.maximumTravelMinutes,
                                "inviteCode": inviteCode,
                                "inviteURL": inviteURL.absoluteString,
                                "expiresAt": Timestamp(date: expiresAt),
                                "status": "waiting",
                                "createdAt": FieldValue.serverTimestamp(),
                                "updatedAt": FieldValue.serverTimestamp()
                            ],
                            forDocument: tripReference
                        )

                        transaction.setData(
                            [
                                "tripID": tripReference.documentID,
                                "active": true,
                                "expiresAt": Timestamp(date: expiresAt),
                                "createdAt": FieldValue.serverTimestamp()
                            ],
                            forDocument: inviteReference
                        )

                        for index in 0..<request.travelerCount {
                            let participantReference = tripReference
                                .collection("participants")
                                .document(index == 0 ? userID : "slot_\(index + 1)")
                            let isOwner = index == 0
                            let participantName = isOwner ? nickname : "친구 \(index + 1)"
                            let participantAvatar = participantAvatars[index]
                            var participantData: [String: Any] = [
                                "slotIndex": index,
                                "uid": isOwner ? userID : NSNull(),
                                "name": participantName,
                                "avatarName": participantAvatar.rawValue,
                                "role": isOwner ? "owner" : "member",
                                "status": isOwner ? "joined" : "waiting"
                            ]
                            if isOwner {
                                participantData["joinedAt"] = FieldValue.serverTimestamp()
                            }
                            transaction.setData(
                                participantData,
                                forDocument: participantReference
                            )
                        }

                        var userData: [String: Any] = [
                            "joinedTripIDs": FieldValue.arrayUnion([tripReference.documentID]),
                            "updatedAt": FieldValue.serverTimestamp()
                        ]
                        if storedAvatar != ownerAvatar {
                            userData["avatarName"] = ownerAvatar.rawValue
                        }
                        transaction.setData(
                            userData,
                            forDocument: database.collection("users").document(userID),
                            merge: true
                        )
                        return tripReference.documentID
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                }

                return try await fetchInvitation(tripID: tripReference.documentID)
            } catch let error as NSError where error.domain == duplicateCodeDomain {
                continue
            }
        }

        throw TripServiceError.inviteCodeGenerationFailed
    }

    static func fetchInvitation(tripID: String) async throws -> TripInvitationSnapshot {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }

        let tripReference = Firestore.firestore().collection("trips").document(tripID)
        let tripDocument = try await tripReference.getDocument()
        guard
            tripDocument.exists,
            let code = tripDocument.get("inviteCode") as? String,
            let urlString = tripDocument.get("inviteURL") as? String,
            let url = URL(string: urlString),
            let expiresAt = (tripDocument.get("expiresAt") as? Timestamp)?.dateValue()
        else {
            throw TripServiceError.tripNotFound
        }

        let calendar = Calendar(identifier: .gregorian)
        let startDate = (tripDocument.get("startAt") as? Timestamp)?.dateValue()
            ?? calendar.startOfDay(for: Date())
        let endDate = (tripDocument.get("endAt") as? Timestamp)?.dateValue()
            ?? calendar.date(byAdding: .day, value: 3, to: startDate)!
        let destinations = tripDocument.get("destinations") as? [[String: Any]]
        let destinationName = destinations?.first?["name"] as? String ?? "도쿄"
        let currentUserID = Auth.auth().currentUser?.uid

        let participantDocuments = try await tripReference
            .collection("participants")
            .order(by: "slotIndex")
            .getDocuments()
        let participants = participantDocuments.documents.map { document in
            let slotIndex = document.get("slotIndex") as? Int ?? 0
            let name = document.get("name") as? String ?? "친구"
            let avatar = (document.get("avatarName") as? String)
                .flatMap { ParticipantAvatar(rawValue: $0) }
                ?? ParticipantAvatar.matched(to: name)
                ?? ParticipantAvatar.assigned(to: name, fallbackIndex: slotIndex)

            return TripInvitationSnapshot.Participant(
                id: slotIndex,
                name: name,
                avatarName: avatar.rawValue,
                hasJoined: document.get("status") as? String == "joined",
                isCurrentUser: document.get("uid") as? String == currentUserID
            )
        }

        return TripInvitationSnapshot(
            tripID: tripID,
            title: tripDocument.get("title") as? String ?? "여행",
            destinationName: destinationName,
            startDate: startDate,
            endDate: endDate,
            code: code,
            url: url,
            expiresAt: expiresAt,
            participants: participants
        )
    }

    static func joinTrip(inviteCode: String) async throws -> TripInvitationSnapshot {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }
        guard let userID = Auth.auth().currentUser?.uid else {
            throw TripServiceError.unauthenticated
        }

        #if DEBUG
        if developmentInviteCodes.contains(inviteCode) {
            try await seedDevelopmentTripIfNeeded(code: inviteCode, currentUserID: userID)
        }
        #endif

        let database = Firestore.firestore()
        let inviteDocument = try await database
            .collection("inviteCodes")
            .document(inviteCode)
            .getDocument()
        guard
            inviteDocument.exists,
            inviteDocument.get("active") as? Bool == true,
            let tripID = inviteDocument.get("tripID") as? String
        else {
            throw TripServiceError.invalidInviteCode
        }
        if let expiresAt = (inviteDocument.get("expiresAt") as? Timestamp)?.dateValue(),
           expiresAt <= Date() {
            throw TripServiceError.expiredInviteCode
        }

        let userDocument = try await database.collection("users").document(userID).getDocument()
        let storedNickname = (userDocument.get("nickname") as? String) ?? "친구"
        let nickname = storedNickname
        let tripReference = database.collection("trips").document(tripID)
        let participants = try await tripReference
            .collection("participants")
            .order(by: "slotIndex")
            .getDocuments()

        if participants.documents.contains(where: { $0.get("uid") as? String == userID }) {
            try await database.collection("users").document(userID).setData(
                [
                    "joinedTripIDs": FieldValue.arrayUnion([tripID]),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
            return try await fetchInvitation(tripID: tripID)
        }
        guard let waitingParticipant = participants.documents.first(where: {
            ($0.get("status") as? String) == "waiting" && !($0.get("uid") is String)
        }) else {
            throw TripServiceError.tripIsFull
        }

        let usedAvatars = Set(
            participants.documents.compactMap { document -> ParticipantAvatar? in
                guard document.get("status") as? String == "joined" else { return nil }
                return (document.get("avatarName") as? String)
                    .flatMap { ParticipantAvatar(rawValue: $0) }
            }
        )
        let reservedAvatar = (waitingParticipant.get("avatarName") as? String)
            .flatMap { ParticipantAvatar(rawValue: $0) }
        let avatar = ParticipantAvatar.availableAssignment(
            preferred: reservedAvatar ?? ParticipantAvatar.matched(to: nickname),
            excluding: usedAvatars
        )
        let participantReference = waitingParticipant.reference
        let joinedParticipantReference = participantReference.parent.document(userID)

        _ = try await database.runTransaction { transaction, errorPointer in
            do {
                let latestParticipant = try transaction.getDocument(participantReference)
                guard
                    latestParticipant.get("status") as? String == "waiting",
                    !(latestParticipant.get("uid") is String)
                else {
                    errorPointer?.pointee = NSError(
                        domain: "FirebaseTripService.ParticipantSlot",
                        code: 409
                    )
                    return nil
                }

                transaction.setData(
                    [
                        "slotIndex": latestParticipant.get("slotIndex") as? Int ?? 0,
                        "uid": userID,
                        "name": nickname,
                        "avatarName": avatar.rawValue,
                        "role": "member",
                        "status": "joined",
                        "joinedAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: joinedParticipantReference,
                    merge: true
                )
                transaction.updateData(
                    [
                        "status": "migrated",
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: participantReference
                )
                transaction.setData(
                    [
                        "avatarName": avatar.rawValue,
                        "joinedTripIDs": FieldValue.arrayUnion([tripID]),
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: database.collection("users").document(userID),
                    merge: true
                )
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        return try await fetchInvitation(tripID: tripID)
    }

    static func fetchUpcomingTrips() async throws -> [UpcomingTripSnapshot] {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }
        guard let userID = Auth.auth().currentUser?.uid else {
            throw TripServiceError.unauthenticated
        }

        #if DEBUG
        for code in developmentInviteCodes.sorted() {
            try await seedDevelopmentTripIfNeeded(code: code, currentUserID: userID)
        }
        #endif

        let database = Firestore.firestore()
        let userReference = database.collection("users").document(userID)
        let userDocument = try await userReference.getDocument()
        var tripIDs = userDocument.get("joinedTripIDs") as? [String] ?? []

        #if DEBUG
        // 개발용 초대 방을 joinedTripIDs 도입 전에 사용한 계정도 복구한다.
        for developmentTripID in developmentTripIDs where !tripIDs.contains(developmentTripID) {
            let developmentTrip = database.collection("trips").document(developmentTripID)
            let membership = try await developmentTrip
                .collection("participants")
                .whereField("uid", isEqualTo: userID)
                .limit(to: 1)
                .getDocuments()
            if !membership.documents.isEmpty {
                tripIDs.append(developmentTripID)
                try await userReference.setData(
                    [
                        "joinedTripIDs": FieldValue.arrayUnion([developmentTripID]),
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    merge: true
                )
            }
        }
        #endif

        // joinedTripIDs 도입 전에 참여한 기존 방은 한 번 찾아 사용자 문서를 보정한다.
        if tripIDs.isEmpty {
            var discoveredTripIDs: [String] = []
            if let tripDocuments = try? await database.collection("trips").getDocuments() {
                for tripDocument in tripDocuments.documents {
                    let membership = try await tripDocument.reference
                        .collection("participants")
                        .whereField("uid", isEqualTo: userID)
                        .limit(to: 1)
                        .getDocuments()
                    if !membership.documents.isEmpty {
                        discoveredTripIDs.append(tripDocument.documentID)
                    }
                }
            }

            if !discoveredTripIDs.isEmpty {
                try await userReference.setData(
                    [
                        "joinedTripIDs": FieldValue.arrayUnion(discoveredTripIDs),
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    merge: true
                )
                tripIDs = discoveredTripIDs
            }
        }

        #if DEBUG
        // 개발용 여행만 예정된 여행 목록에 유지한다.
        tripIDs = tripIDs.filter { developmentTripIDs.contains($0) }
        try await userReference.setData(
            [
                "joinedTripIDs": tripIDs,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
        #endif

        var trips: [UpcomingTripSnapshot] = []
        for tripID in Set(tripIDs) {
            let tripReference = database.collection("trips").document(tripID)
            let tripDocument = try await tripReference.getDocument()
            guard
                tripDocument.exists,
                let startDate = (tripDocument.get("startAt") as? Timestamp)?.dateValue(),
                let endDate = (tripDocument.get("endAt") as? Timestamp)?.dateValue()
            else { continue }

            let destination = (tripDocument.get("destinations") as? [[String: Any]])?.first
            trips.append(
                UpcomingTripSnapshot(
                    tripID: tripReference.documentID,
                    destinationName: destination?["name"] as? String ?? "여행",
                    countryName: destination?["country"] as? String ?? "",
                    startDate: startDate,
                    endDate: endDate
                )
            )
        }

        return trips.sorted { $0.startDate < $1.startDate }
    }

    private struct DevelopmentParticipant {
        let name: String
        let avatar: ParticipantAvatar
        let uid: String?
        let isJoined: Bool
    }

    private struct DevelopmentTrip {
        let destinationID: String
        let destinationName: String
        let countryName: String
        let startDate: Date
        let endDate: Date
        let participants: [DevelopmentParticipant]
    }

    private static func seedDevelopmentTripIfNeeded(
        code: String,
        currentUserID: String
    ) async throws {
        guard developmentInviteCodes.contains(code) else { return }

        let database = Firestore.firestore()
        let userReference = database.collection("users").document(currentUserID)
        let userDocument = try await userReference.getDocument()
        let currentUserName = userDocument.get("nickname") as? String ?? "나"
        let trip = developmentTrip(
            code: code,
            currentUserID: currentUserID,
            currentUserName: currentUserName
        )
        let tripReference = database.collection("trips").document("development-trip-\(code)")
        let inviteReference = database.collection("inviteCodes").document(code)
        let expiresAt = Date().addingTimeInterval(developmentInviteDuration)
        let inviteURL = makeInviteURL(code: code, expiresAt: expiresAt)
        let batch = database.batch()

        batch.setData(
            [
                "ownerID": currentUserID,
                "title": "\(trip.destinationName) 여행",
                "destinationIDs": [trip.destinationID],
                "destinations": [[
                    "id": trip.destinationID,
                    "country": trip.countryName,
                    "name": trip.destinationName
                ]],
                "startAt": Timestamp(date: trip.startDate),
                "endAt": Timestamp(date: trip.endDate),
                "travelerCount": trip.participants.count,
                "transportation": "대중교통",
                "maximumTravelMinutes": 30,
                "inviteCode": code,
                "inviteURL": inviteURL.absoluteString,
                "expiresAt": Timestamp(date: expiresAt),
                "status": "waiting",
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: tripReference,
            merge: true
        )
        batch.setData(
            [
                "tripID": tripReference.documentID,
                "active": true,
                "expiresAt": Timestamp(date: expiresAt),
                "createdAt": FieldValue.serverTimestamp()
            ],
            forDocument: inviteReference,
            merge: true
        )

        let participantEntries = trip.participants.enumerated().map { index, participant in
            let documentID: String
            if participant.uid == currentUserID {
                documentID = currentUserID
            } else if participant.name == "관리자관리자" {
                documentID = "development-admin"
            } else if participant.isJoined {
                documentID = "development-member-\(index + 1)"
            } else {
                documentID = "slot_\(index + 1)"
            }
            return (index: index, participant: participant, documentID: documentID)
        }
        let activeDocumentIDs = Set(participantEntries.map(\.documentID))
        let knownDocumentIDs = ["development-admin"]
            + (1...4).flatMap { ["slot_\($0)", "development-member-\($0)"] }
        for documentID in knownDocumentIDs where !activeDocumentIDs.contains(documentID) {
            batch.deleteDocument(
                tripReference.collection("participants").document(documentID)
            )
        }

        for entry in participantEntries {
            let index = entry.index
            let participant = entry.participant
            var data: [String: Any] = [
                "slotIndex": index,
                "uid": participant.uid ?? NSNull(),
                "name": participant.name,
                "avatarName": participant.avatar.rawValue,
                "role": index == 0 ? "owner" : "member",
                "status": participant.isJoined ? "joined" : "waiting",
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if participant.isJoined {
                data["joinedAt"] = FieldValue.serverTimestamp()
            }
            batch.setData(
                data,
                forDocument: tripReference.collection("participants").document(entry.documentID),
                merge: true
            )
        }

        batch.setData(
            [
                "joinedTripIDs": FieldValue.arrayUnion([tripReference.documentID]),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: userReference,
            merge: true
        )
        try await batch.commit()
    }

    private static func developmentTrip(
        code: String,
        currentUserID: String,
        currentUserName: String
    ) -> DevelopmentTrip {
        let calendar = Calendar(identifier: .gregorian)
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }
        let currentUser = DevelopmentParticipant(
            name: currentUserName,
            avatar: .juni,
            uid: currentUserID,
            isJoined: true
        )

        switch code {
        case "987654":
            return DevelopmentTrip(
                destinationID: "shanghai",
                destinationName: "상하이",
                countryName: "중국",
                startDate: date(2026, 12, 5),
                endDate: date(2026, 12, 8),
                participants: [
                    .init(name: "자리자관지리관", avatar: .tae, uid: "development-987654-member-1", isJoined: true),
                    .init(name: "관리자관리자", avatar: .header, uid: "development-admin", isJoined: true),
                    currentUser
                ]
            )
        case "111111":
            return DevelopmentTrip(
                destinationID: "sydney",
                destinationName: "시드니",
                countryName: "호주",
                startDate: date(2027, 3, 2),
                endDate: date(2027, 3, 9),
                participants: [
                    .init(name: "관리자", avatar: .grae, uid: "development-11111111-member-1", isJoined: true),
                    .init(name: "자리자관지리관", avatar: .tae, uid: nil, isJoined: false),
                    .init(name: "관리자관리자", avatar: .header, uid: "development-admin", isJoined: true),
                    currentUser
                ]
            )
        default:
            return DevelopmentTrip(
                destinationID: "tokyo",
                destinationName: "도쿄",
                countryName: "일본",
                startDate: date(2026, 11, 22),
                endDate: date(2026, 11, 25),
                participants: [
                    .init(name: "관리자관리자", avatar: .header, uid: "development-admin", isJoined: true),
                    currentUser
                ]
            )
        }
    }

    private static func makeInviteURL(code: String, expiresAt: Date) -> URL {
        var components = URLComponents(string: inviteURLBase)!
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "endTime", value: ISO8601DateFormatter().string(from: expiresAt))
        ]
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: ":", with: "%3A")
        return components.url!
    }
}

enum TripServiceError: LocalizedError {
    case firebaseNotConfigured
    case unauthenticated
    case tripNotFound
    case invalidInviteCode
    case expiredInviteCode
    case tripIsFull
    case inviteCodeGenerationFailed

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: "Firebase 설정을 확인해 주세요."
        case .unauthenticated: "로그인이 필요합니다."
        case .tripNotFound: "여행 정보를 찾을 수 없습니다."
        case .invalidInviteCode: "유효하지 않은 초대 코드입니다."
        case .expiredInviteCode: "초대 코드의 유효 기간이 지났습니다."
        case .tripIsFull: "이미 모든 친구가 참여한 여행입니다."
        case .inviteCodeGenerationFailed: "초대 코드를 만들지 못했습니다. 다시 시도해 주세요."
        }
    }
}
