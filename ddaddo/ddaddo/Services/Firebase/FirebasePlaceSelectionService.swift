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

        var result: [MemberPlacePins] = []
        for participant in participants.documents {
            guard
                participant.get("status") as? String == "joined",
                let avatarName = participant.get("avatarName") as? String,
                let avatar = ParticipantAvatar(rawValue: avatarName)
            else { continue }

            // 개발용 관리자는 인증 사용자가 아니므로 보안 규칙상 하위 컬렉션을
            // 읽을 수 없다. 해당 핀은 HomeFeature의 고정 관리자 데이터로 보완한다.
            if tripID == "development-trip-123456",
               participant.documentID == "development-admin" {
                continue
            }

            let placeDocuments: QuerySnapshot
            do {
                placeDocuments = try await participant.reference
                    .collection("places")
                    .order(by: "createdAt")
                    .getDocuments()
            } catch {
                // 다른 참여자의 장소 읽기 권한이 아직 배포되지 않은 환경에서도
                // 내 장소와 로컬 fallback으로 화면 흐름은 계속 진행한다.
                continue
            }
            let places = placeDocuments.documents.compactMap(makePinnedPlace)

            result.append(
                MemberPlacePins(
                    member: TripMember(avatar: avatar),
                    places: places,
                    isConfirmed: participant.get("placeSelectionConfirmed") as? Bool ?? false
                )
            )
        }
        return result
    }

    static func savePlace(_ place: PinnedPlace, tripID: String) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        try await participant.collection("places").document(place.id).setData(
            [
                "id": place.id,
                "name": place.name,
                "description": place.description,
                "category": place.category,
                "latitude": place.latitude,
                "longitude": place.longitude,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
        try await participant.setData(
            [
                "placeSelectionConfirmed": false,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    static func deletePlace(placeID: String, tripID: String) async throws {
        let participant = try await currentParticipantReference(tripID: tripID)
        try await participant.collection("places").document(placeID).delete()
        try await participant.setData(
            [
                "placeSelectionConfirmed": false,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
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
            let isDevelopmentAdmin = tripID == "development-trip-123456"
                && document.documentID == "development-admin"
            return MemberGroupConfirmation(
                member: member,
                name: document.get("name") as? String ?? "친구",
                isConfirmed: isDevelopmentAdmin
                    || (document.get("groupingConfirmed") as? Bool ?? false)
            )
        }
    }

    private static func currentParticipantReference(
        tripID: String
    ) async throws -> DocumentReference {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw TripServiceError.unauthenticated
        }

        let participants = try await Firestore.firestore()
            .collection("trips")
            .document(tripID)
            .collection("participants")
            .whereField("uid", isEqualTo: userID)
            .limit(to: 1)
            .getDocuments()
        guard let participant = participants.documents.first else {
            throw TripServiceError.tripNotFound
        }

        guard participant.documentID != userID else {
            return participant.reference
        }

        // 예전 데이터는 slot_2 같은 슬롯 문서에 uid만 기록되어 있다.
        // 장소 하위 컬렉션 규칙이 인증 uid 문서만 허용하므로 최초 접근 시
        // 참가자 메타데이터를 participants/{uid}로 옮긴다.
        let uidReference = participant.reference.parent.document(userID)
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
            thumbnailName: "DDMockPlaceVillage",
            category: document.get("category") as? String ?? "장소",
            latitude: latitude,
            longitude: longitude
        )
    }
}
