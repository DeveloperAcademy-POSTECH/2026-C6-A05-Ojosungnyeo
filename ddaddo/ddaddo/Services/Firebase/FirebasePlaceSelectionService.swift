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

            let placeDocuments = try await participant.reference
                .collection("places")
                .order(by: "createdAt")
                .getDocuments()
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
        let participant = try await currentParticipant(tripID: tripID)
        try await participant.reference.collection("places").document(place.id).setData(
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
        try await participant.reference.setData(
            [
                "placeSelectionConfirmed": false,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    static func deletePlace(placeID: String, tripID: String) async throws {
        let participant = try await currentParticipant(tripID: tripID)
        try await participant.reference.collection("places").document(placeID).delete()
        try await participant.reference.setData(
            [
                "placeSelectionConfirmed": false,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    static func confirmPlaces(tripID: String) async throws {
        let participant = try await currentParticipant(tripID: tripID)
        try await participant.reference.setData(
            [
                "placeSelectionConfirmed": true,
                "placeSelectionConfirmedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    private static func currentParticipant(
        tripID: String
    ) async throws -> QueryDocumentSnapshot {
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
        return participant
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
