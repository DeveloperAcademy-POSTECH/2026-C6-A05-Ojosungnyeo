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

        let database = Firestore.firestore()
        let userDocument = try await database.collection("users").document(userID).getDocument()
        let nickname = (userDocument.get("nickname") as? String) ?? "나"
        let storedAvatar = (userDocument.get("avatarName") as? String)
            .flatMap { ParticipantAvatar(rawValue: $0) }
        let ownerAvatar = ParticipantAvatar.matched(to: nickname)
            ?? storedAvatar
            ?? ParticipantAvatar.assigned(to: nickname, fallbackIndex: 0)

        for _ in 0..<5 {
            let tripReference = database.collection("trips").document()
            let inviteCode = String(format: "%06d", Int.random(in: 0...999_999))
            let inviteReference = database.collection("inviteCodes").document(inviteCode)
            let expiresAt = Date().addingTimeInterval(inviteDuration)
            let inviteURL = makeInviteURL(code: inviteCode)

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
                            let participantAvatar = isOwner
                                ? ownerAvatar
                                : ParticipantAvatar.assigned(to: participantName, fallbackIndex: index)
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

                        if storedAvatar != ownerAvatar {
                            transaction.setData(
                                ["avatarName": ownerAvatar.rawValue],
                                forDocument: database.collection("users").document(userID),
                                merge: true
                            )
                        }
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

        let participantDocuments = try await tripReference
            .collection("participants")
            .order(by: "slotIndex")
            .getDocuments()
        let participants = participantDocuments.documents.map { document in
            let slotIndex = document.get("slotIndex") as? Int ?? 0
            let name = document.get("name") as? String ?? "친구"
            let avatar = ParticipantAvatar.matched(to: name)
                ?? (document.get("avatarName") as? String)
                    .flatMap { ParticipantAvatar(rawValue: $0) }
                ?? ParticipantAvatar.assigned(to: name, fallbackIndex: slotIndex)

            return TripInvitationSnapshot.Participant(
                id: slotIndex,
                name: name,
                avatarName: avatar.rawValue,
                hasJoined: document.get("status") as? String == "joined"
            )
        }

        return TripInvitationSnapshot(
            tripID: tripID,
            code: code,
            url: url,
            expiresAt: expiresAt,
            participants: participants
        )
    }

    private static func makeInviteURL(code: String) -> URL {
        var components = URLComponents(string: inviteURLBase)!
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url!
    }
}

enum TripServiceError: LocalizedError {
    case firebaseNotConfigured
    case unauthenticated
    case tripNotFound
    case inviteCodeGenerationFailed

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: "Firebase 설정을 확인해 주세요."
        case .unauthenticated: "로그인이 필요합니다."
        case .tripNotFound: "여행 정보를 찾을 수 없습니다."
        case .inviteCodeGenerationFailed: "초대 코드를 만들지 못했습니다. 다시 시도해 주세요."
        }
    }
}
