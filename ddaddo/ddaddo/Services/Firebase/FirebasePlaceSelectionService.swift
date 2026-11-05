import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirebasePlaceSelectionService {
    static func fetchMemberPlaces(tripID: String) async throws -> [MemberPlacePins] {
        guard FirebaseService.isConfigured else {
            throw TripServiceError.firebaseNotConfigured
        }

        let participants = try await Firestore.firestore()
            .collection("trips")
            .document(tripID)
            .collection("participants")
            .order(by: "slotIndex")
            .getDocuments()

        let currentUserID = Auth.auth().currentUser?.uid
        var result: [MemberPlacePins] = []
        var seenMembers = Set<TripMember>()
        for participant in orderedParticipantDocuments(participants.documents) {
            guard
                participant.get("status") as? String == "joined",
                let avatarName = participant.get("avatarName") as? String,
                let avatar = ParticipantAvatar(rawValue: avatarName)
            else { continue }
            let member = TripMember(avatar: avatar)
            guard seenMembers.insert(member).inserted else { continue }

            let placeDocuments: QuerySnapshot
            let places: [PinnedPlace]
            if let storedPlaces = participant.get("selectedPlaces") as? [[String: Any]] {
                places = storedPlaces.compactMap(makePinnedPlace)
            } else {
                do {
                    placeDocuments = try await participant.reference
                        .collection("places")
                        .order(by: "createdAt")
                        .getDocuments()
                    places = placeDocuments.documents.compactMap(makePinnedPlace)
                    if participant.documentID == currentUserID {
                        try? await participant.reference.setData(
                            ["selectedPlaces": places.map(placeData)],
                            merge: true
                        )
                    }
                } catch {
                    places = []
                }
            }

            result.append(
                MemberPlacePins(
                    member: member,
                    places: places,
                    isConfirmed: participant.get("placeSelectionConfirmed") as? Bool ?? false
                )
            )
        }
        return result
    }

    nonisolated static func observeMemberPlaces(
        tripID: String
    ) -> AsyncThrowingStream<[MemberPlacePins], Error> {
        AsyncThrowingStream { continuation in
            let registration = Firestore.firestore()
                .collection("trips")
                .document(tripID)
                .collection("participants")
                .order(by: "slotIndex")
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let documents = snapshot?.documents else { return }
                    var seenMembers = Set<TripMember>()
                    let values = orderedParticipantDocuments(documents).compactMap { document -> MemberPlacePins? in
                        guard
                            document.get("status") as? String == "joined",
                            let avatarName = document.get("avatarName") as? String,
                            let avatar = ParticipantAvatar(rawValue: avatarName)
                        else { return nil }
                        let member = TripMember(avatar: avatar)
                        guard seenMembers.insert(member).inserted else { return nil }
                        let places = (document.get("selectedPlaces") as? [[String: Any]] ?? [])
                            .compactMap(makePinnedPlace)
                        return MemberPlacePins(
                            member: member,
                            places: places,
                            isConfirmed: document.get("placeSelectionConfirmed") as? Bool ?? false
                        )
                    }
                    continuation.yield(values)
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    static func savePlace(_ place: PinnedPlace, tripID: String) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        let document = try await participant.getDocument()
        var places = try await storedPlaceData(document: document, participant: participant)
        places.removeAll { $0["id"] as? String == place.id }
        places.append(placeData(place))
        try await participant.setData([
            "selectedPlaces": places,
            "placeSelectionConfirmed": false,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    static func deletePlace(placeID: String, tripID: String) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        let document = try await participant.getDocument()
        var places = try await storedPlaceData(document: document, participant: participant)
        places.removeAll { $0["id"] as? String == placeID }
        try await participant.setData([
            "selectedPlaces": places,
            "placeSelectionConfirmed": false,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    static func replacePlaces(_ places: [PinnedPlace], tripID: String) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        try await participant.setData([
            "selectedPlaces": places.map(placeData),
            "placeSelectionConfirmed": false,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    static func confirmPlaces(tripID: String) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        try await participant.setData(
            [
                "placeSelectionConfirmed": true,
                "placeSelectionConfirmedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    static func joinGroup(tripID: String, groupID: String) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        try await participant.setData(
            [
                "joinedGroupIDs": FieldValue.arrayUnion([groupID]),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    static func setGroupConfirmation(
        tripID: String,
        groupID: String,
        isConfirmed: Bool,
        sendsPush: Bool
    ) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        var data: [String: Any] = [
            "confirmedGroupIDs": isConfirmed
                ? FieldValue.arrayUnion([groupID])
                : FieldValue.arrayRemove([groupID]),
            "groupingConfirmed": false,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if !isConfirmed, sendsPush {
            data["groupCancellationEvent"] = [
                "id": UUID().uuidString,
                "groupID": groupID,
                "createdAt": FieldValue.serverTimestamp()
            ]
        }
        try await participant.setData(
            data,
            merge: true
        )
    }

    static func updateGroupPlaces(
        tripID: String,
        groupID: String,
        orderedPlaceIDs: [String],
        deletedPlaceID: String?
    ) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        let snapshot = try await participant.getDocument()
        var deletedPlaceIDsByGroupID = snapshot.get("deletedPlaceIDsByGroupID")
            as? [String: [String]] ?? [:]
        if let deletedPlaceID {
            var deletedPlaceIDs = Set(deletedPlaceIDsByGroupID[groupID] ?? [])
            deletedPlaceIDs.insert(deletedPlaceID)
            deletedPlaceIDsByGroupID[groupID] = deletedPlaceIDs.sorted()
        }
        var orderedPlaceIDsByGroupID = snapshot.get("orderedPlaceIDsByGroupID")
            as? [String: [String]] ?? [:]
        orderedPlaceIDsByGroupID[groupID] = orderedPlaceIDs

        try await participant.setData(
            [
                "deletedPlaceIDsByGroupID": deletedPlaceIDsByGroupID,
                "orderedPlaceIDsByGroupID": orderedPlaceIDsByGroupID,
                "groupEditEvent": [
                    "id": UUID().uuidString,
                    "groupID": groupID,
                    "kind": deletedPlaceID == nil ? "reordered" : "deleted",
                    "deletedPlaceID": deletedPlaceID.map { $0 as Any } ?? NSNull(),
                    "createdAt": FieldValue.serverTimestamp()
                ],
                "confirmedGroupIDs": FieldValue.arrayRemove([groupID]),
                "groupingConfirmed": false,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    nonisolated static func observeGroupMemberships(
        tripID: String
    ) -> AsyncThrowingStream<[MemberGroupMembership], Error> {
        AsyncThrowingStream { continuation in
            let registration = Firestore.firestore()
                .collection("trips")
                .document(tripID)
                .collection("participants")
                .order(by: "slotIndex")
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let documents = snapshot?.documents else { return }
                    var seenMembers = Set<TripMember>()
                    let values = orderedParticipantDocuments(documents).compactMap {
                        document -> MemberGroupMembership? in
                        guard
                            document.get("status") as? String == "joined",
                            let avatarName = document.get("avatarName") as? String,
                            let avatar = ParticipantAvatar(rawValue: avatarName)
                        else { return nil }
                        let member = TripMember(avatar: avatar)
                        guard seenMembers.insert(member).inserted else { return nil }
                        let editData = document.get("groupEditEvent") as? [String: Any]
                        let latestGroupEdit: GroupEditEvent?
                        if let editID = editData?["id"] as? String,
                           let groupID = editData?["groupID"] as? String {
                            latestGroupEdit = GroupEditEvent(
                                id: editID,
                                groupID: groupID,
                                editor: member,
                                editorName: document.get("name") as? String ?? "친구"
                            )
                        } else {
                            latestGroupEdit = nil
                        }
                        return MemberGroupMembership(
                            member: member,
                            groupIDs: document.get("joinedGroupIDs") as? [String] ?? [],
                            confirmedGroupIDs: document.get("confirmedGroupIDs") as? [String] ?? [],
                            deletedPlaceIDsByGroupID: document.get("deletedPlaceIDsByGroupID")
                                as? [String: [String]] ?? [:],
                            orderedPlaceIDsByGroupID: document.get("orderedPlaceIDsByGroupID")
                                as? [String: [String]] ?? [:],
                            latestGroupEdit: latestGroupEdit
                        )
                    }
                    continuation.yield(values)
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    static func confirmGroups(tripID: String, groupIDs: [String]) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        try await participant.setData(
            [
                "groupingConfirmed": true,
                "confirmedGroupIDs": groupIDs,
                "groupingConfirmedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    static func fetchGroupConfirmations(
        tripID: String
    ) async throws -> [MemberGroupConfirmation] {
        let participants = try await Firestore.firestore()
            .collection("trips")
            .document(tripID)
            .collection("participants")
            .order(by: "slotIndex")
            .getDocuments()

        var seenMembers = Set<TripMember>()
        return participants.documents.compactMap { document in
            guard
                document.get("status") as? String == "joined",
                let avatarName = document.get("avatarName") as? String,
                let avatar = ParticipantAvatar(rawValue: avatarName)
            else { return nil }
            let member = TripMember(avatar: avatar)
            guard seenMembers.insert(member).inserted else { return nil }
            return MemberGroupConfirmation(
                member: member,
                name: document.get("name") as? String ?? "친구",
                isConfirmed: document.get("groupingConfirmed") as? Bool ?? false,
                confirmedGroupIDs: document.get("confirmedGroupIDs") as? [String] ?? []
            )
        }
    }

    static func completeGrouping(tripID: String) async throws {
        try await Firestore.firestore()
            .collection("trips")
            .document(tripID)
            .setData(
                [
                    "status": "itinerary",
                    "groupingCompletedAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
    }

    private static func currentParticipantReference(
        tripID: String
    ) async throws -> DocumentReference {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw TripServiceError.unauthenticated
        }

        let participants = Firestore.firestore()
            .collection("trips")
            .document(tripID)
            .collection("participants")
        let uidReference = participants.document(userID)
        let uidDocument = try await uidReference.getDocument()
        if uidDocument.exists,
           uidDocument.get("status") as? String == "joined" {
            return uidReference
        }

        let legacyParticipants = try await participants
            .whereField("uid", isEqualTo: userID)
            .limit(to: 1)
            .getDocuments()
        guard let participant = legacyParticipants.documents.first else {
            throw TripServiceError.tripNotFound
        }

        // 예전 데이터는 slot_2 같은 슬롯 문서에 uid만 기록되어 있다.
        // 장소 하위 컬렉션 규칙이 인증 uid 문서만 허용하므로 최초 접근 시
        // 참가자 메타데이터를 participants/{uid}로 옮긴다.
        var participantData = participant.data()
        participantData["uid"] = userID
        participantData["status"] = "joined"
        participantData["updatedAt"] = FieldValue.serverTimestamp()
        try await uidReference.setData(participantData, merge: true)

        // 이전 슬롯은 중복 참가자로 노출되지 않도록 정리한다. 이 갱신 권한이
        // 없는 구형 규칙이어도 UID 문서 저장은 이미 완료되므로 흐름은 유지한다.
        try? await participant.reference.setData(
            [
                "status": "migrated",
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
        return uidReference
    }

    private static func makePinnedPlace(_ document: QueryDocumentSnapshot) -> PinnedPlace? {
        guard
            let name = document.get("name") as? String,
            let latitude = document.get("latitude") as? Double,
            let longitude = document.get("longitude") as? Double
        else { return nil }

        return PinnedPlace(
            id: document.get("id") as? String ?? document.documentID,
            name: name,
            description: document.get("description") as? String ?? "",
            thumbnailName: "",
            category: document.get("category") as? String ?? "장소",
            latitude: latitude,
            longitude: longitude
        )
    }

    nonisolated private static func makePinnedPlace(_ data: [String: Any]) -> PinnedPlace? {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String,
            let latitude = data["latitude"] as? Double,
            let longitude = data["longitude"] as? Double
        else { return nil }
        return PinnedPlace(
            id: id,
            name: name,
            description: data["description"] as? String ?? "",
            thumbnailName: "",
            category: data["category"] as? String ?? "장소",
            latitude: latitude,
            longitude: longitude
        )
    }

    private static func placeData(_ place: PinnedPlace) -> [String: Any] {
        [
            "id": place.id,
            "name": place.name,
            "description": place.description,
            "category": place.category,
            "latitude": place.latitude,
            "longitude": place.longitude
        ]
    }

    private static func storedPlaceData(
        document: DocumentSnapshot,
        participant: DocumentReference
    ) async throws -> [[String: Any]] {
        if let places = document.get("selectedPlaces") as? [[String: Any]] {
            return places
        }
        let legacyPlaces = try await participant.collection("places")
            .order(by: "createdAt")
            .getDocuments()
        return legacyPlaces.documents
            .compactMap(makePinnedPlace)
            .map(placeData)
    }

    nonisolated private static func orderedParticipantDocuments(
        _ documents: [QueryDocumentSnapshot]
    ) -> [QueryDocumentSnapshot] {
        documents.sorted { lhs, rhs in
            let lhsUID = lhs.get("uid") as? String
            let rhsUID = rhs.get("uid") as? String
            let lhsIsCanonical = lhsUID != nil && lhs.documentID == lhsUID
            let rhsIsCanonical = rhsUID != nil && rhs.documentID == rhsUID
            if lhsIsCanonical != rhsIsCanonical { return lhsIsCanonical }
            return (lhs.get("slotIndex") as? Int ?? 0)
                < (rhs.get("slotIndex") as? Int ?? 0)
        }
    }
}
