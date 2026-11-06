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
    private static let duplicateCodeDomain = "FirebaseTripService.DuplicateInviteCode"

    static func createTrip(_ request: TripCreationRequest) async throws -> TripInvitationSnapshot {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }
        guard let userID = Auth.auth().currentUser?.uid else {
            throw TripServiceError.unauthenticated
        }
        guard (1...4).contains(request.travelerCount) else {
            throw TripServiceError.tripIsFull
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
                            "dismissedTripIDs": FieldValue.arrayRemove([tripReference.documentID]),
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
        var seenUserIDs = Set<String>()
        let orderedDocuments = participantDocuments.documents.sorted { lhs, rhs in
            let lhsUID = lhs.get("uid") as? String
            let rhsUID = rhs.get("uid") as? String
            let lhsIsCanonical = lhsUID != nil && lhs.documentID == lhsUID
            let rhsIsCanonical = rhsUID != nil && rhs.documentID == rhsUID
            if lhsIsCanonical != rhsIsCanonical { return lhsIsCanonical }
            let lhsSlot = lhs.get("slotIndex") as? Int ?? 0
            let rhsSlot = rhs.get("slotIndex") as? Int ?? 0
            return lhsSlot < rhsSlot
        }
        let participants = Array(orderedDocuments.compactMap { document -> TripInvitationSnapshot.Participant? in
            let status = document.get("status") as? String
            guard status == "joined" || status == "waiting" else { return nil }
            if let uid = document.get("uid") as? String,
               !seenUserIDs.insert(uid).inserted {
                return nil
            }
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
        }.prefix(4))

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
                    "dismissedTripIDs": FieldValue.arrayRemove([tripID]),
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
                        "dismissedTripIDs": FieldValue.arrayRemove([tripID]),
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

        let database = Firestore.firestore()
        let userReference = database.collection("users").document(userID)
        let userDocument = try await userReference.getDocument()
        let joinedTripIDs = userDocument.get("joinedTripIDs") as? [String] ?? []
        let dismissedTripIDs = Set(userDocument.get("dismissedTripIDs") as? [String] ?? [])
        let tripIDs = Set(joinedTripIDs).filter {
            !$0.hasPrefix("development-trip-") && !dismissedTripIDs.contains($0)
        }

        let trips = try await withThrowingTaskGroup(
            of: UpcomingTripSnapshot?.self,
            returning: [UpcomingTripSnapshot].self
        ) { group in
            for tripID in tripIDs {
                group.addTask {
                    let document = try await Firestore.firestore()
                        .collection("trips")
                        .document(tripID)
                        .getDocument()
                    guard
                        document.exists,
                        let startDate = (document.get("startAt") as? Timestamp)?.dateValue(),
                        let endDate = (document.get("endAt") as? Timestamp)?.dateValue()
                    else { return nil }

                    let destination = (document.get("destinations") as? [[String: Any]])?.first
                    let progress: UpcomingTripSnapshot.Progress
                    if document.get("status") as? String == "itinerary" {
                        progress = .itinerary
                    } else {
                        let participants = try await document.reference
                            .collection("participants")
                            .getDocuments()
                            .documents
                            .filter { $0.get("status") as? String == "joined" }
                        let hasFinishedPlaceSelection = !participants.isEmpty
                            && participants.allSatisfy {
                                $0.get("placeSelectionConfirmed") as? Bool == true
                            }
                        progress = hasFinishedPlaceSelection ? .placeGrouping : .placeSelection
                    }
                    return UpcomingTripSnapshot(
                        tripID: document.documentID,
                        destinationName: destination?["name"] as? String ?? "여행",
                        countryName: destination?["country"] as? String ?? "",
                        startDate: startDate,
                        endDate: endDate,
                        progress: progress
                    )
                }
            }

            var snapshots: [UpcomingTripSnapshot] = []
            for try await snapshot in group {
                if let snapshot { snapshots.append(snapshot) }
            }
            return snapshots
        }

        return trips.sorted { $0.startDate < $1.startDate }
    }

    static func deleteUpcomingTrip(tripID: String) async throws {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }
        guard let userID = Auth.auth().currentUser?.uid else {
            throw TripServiceError.unauthenticated
        }

        try await Firestore.firestore()
            .collection("users")
            .document(userID)
            .setData(
                [
                    "joinedTripIDs": FieldValue.arrayRemove([tripID]),
                    "dismissedTripIDs": FieldValue.arrayUnion([tripID]),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
    }

    static func saveItinerary(_ request: TripItinerarySaveRequest) async throws {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }
        guard let userID = Auth.auth().currentUser?.uid else {
            throw TripServiceError.unauthenticated
        }

        let database = Firestore.firestore()
        let tripReference = database.collection("trips").document(request.tripID)
        let participantDocument = try await tripReference
            .collection("participants")
            .document(userID)
            .getDocument()
        guard participantDocument.exists,
              participantDocument.get("status") as? String == "joined" else {
            throw TripServiceError.notTripParticipant
        }

        let courseData: [[String: Any]] = request.courses.map { course in
            [
                "id": course.id,
                "title": course.title,
                "placeNames": course.placeNames,
                "categories": course.categories,
                "memberIDs": course.memberIDs,
                "durationMinutes": course.durationMinutes,
                "places": course.places.map {
                    [
                        "name": $0.name,
                        "category": $0.category,
                        "latitude": $0.latitude,
                        "longitude": $0.longitude
                    ]
                }
            ]
        }
        let scheduleData: [[String: Any]] = request.schedules.map { schedule in
            var data: [String: Any] = [
                "id": schedule.id,
                "courseID": schedule.courseID,
                "day": schedule.day,
                "startMinuteOfDay": schedule.startMinuteOfDay
            ]
            if let branchGroupID = schedule.branchGroupID {
                data["branchGroupID"] = branchGroupID
            }
            return data
        }

        let batch = database.batch()
        batch.setData(
            [
                "courses": courseData,
                "schedules": scheduleData,
                "updatedBy": userID,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: tripReference.collection("itinerary").document("current")
        )
        batch.setData(
            [
                "status": "itinerary",
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: tripReference,
            merge: true
        )
        try await batch.commit()
    }

    static func fetchItinerary(tripID: String) async throws -> TripItinerarySnapshot? {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }
        guard Auth.auth().currentUser != nil else {
            throw TripServiceError.unauthenticated
        }

        let document = try await Firestore.firestore()
            .collection("trips")
            .document(tripID)
            .collection("itinerary")
            .document("current")
            .getDocument()
        return itinerarySnapshot(from: document)
    }

    static func observeItinerary(
        tripID: String
    ) -> AsyncThrowingStream<TripItinerarySnapshot?, Error> {
        AsyncThrowingStream { continuation in
            guard FirebaseService.isConfigured else {
                continuation.finish(throwing: TripServiceError.firebaseNotConfigured)
                return
            }
            guard Auth.auth().currentUser != nil else {
                continuation.finish(throwing: TripServiceError.unauthenticated)
                return
            }

            let listener = Firestore.firestore()
                .collection("trips")
                .document(tripID)
                .collection("itinerary")
                .document("current")
                .addSnapshotListener { document, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let document else {
                        continuation.yield(nil)
                        return
                    }
                    continuation.yield(itinerarySnapshot(from: document))
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    private static func itinerarySnapshot(from document: DocumentSnapshot) -> TripItinerarySnapshot? {
        guard document.exists else { return nil }

        let courses: [TripItinerarySaveRequest.Course] =
            (document.get("courses") as? [[String: Any]] ?? []).compactMap { data -> TripItinerarySaveRequest.Course? in
            guard let id = data["id"] as? Int,
                  let title = data["title"] as? String else { return nil }
            return TripItinerarySaveRequest.Course(
                id: id,
                title: title,
                placeNames: data["placeNames"] as? [String] ?? [],
                categories: data["categories"] as? [String] ?? [],
                memberIDs: data["memberIDs"] as? [String] ?? [],
                durationMinutes: data["durationMinutes"] as? Int ?? 60,
                places: (data["places"] as? [[String: Any]] ?? []).compactMap { place in
                    guard let name = place["name"] as? String,
                          let latitude = place["latitude"] as? Double,
                          let longitude = place["longitude"] as? Double
                    else { return nil }
                    return ItineraryPlace(
                        name: name,
                        category: place["category"] as? String ?? "",
                        latitude: latitude,
                        longitude: longitude
                    )
                }
            )
        }
        let schedules: [TripItinerarySaveRequest.Schedule] =
            (document.get("schedules") as? [[String: Any]] ?? []).compactMap { data -> TripItinerarySaveRequest.Schedule? in
            guard let id = data["id"] as? Int,
                  let courseID = data["courseID"] as? Int,
                  let day = data["day"] as? String,
                  let startMinute = data["startMinuteOfDay"] as? Int else { return nil }
            return TripItinerarySaveRequest.Schedule(
                id: id,
                courseID: courseID,
                day: day,
                startMinuteOfDay: startMinute,
                branchGroupID: data["branchGroupID"] as? Int
            )
        }
        return TripItinerarySnapshot(courses: courses, schedules: schedules)
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
    case notTripParticipant

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: "Firebase 설정을 확인해 주세요."
        case .unauthenticated: "로그인이 필요합니다."
        case .tripNotFound: "여행 정보를 찾을 수 없습니다."
        case .invalidInviteCode: "유효하지 않은 초대 코드입니다."
        case .expiredInviteCode: "초대 코드의 유효 기간이 지났습니다."
        case .tripIsFull: "이미 모든 친구가 참여한 여행입니다."
        case .inviteCodeGenerationFailed: "초대 코드를 만들지 못했습니다. 다시 시도해 주세요."
        case .notTripParticipant: "이 여행의 참여자만 일정을 저장할 수 있습니다."
        }
    }
}
