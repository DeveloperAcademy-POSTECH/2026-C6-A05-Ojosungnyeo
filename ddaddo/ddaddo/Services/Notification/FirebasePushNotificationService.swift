//
//  FirebasePushNotificationService.swift
//  ddaddo
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirebasePushNotificationService {
    static func saveRegistrationID(_ registrationID: String) async throws {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        try await Firestore.firestore()
            .collection("users")
            .document(userID)
            .setData(
                [
                    "fcmTokens": FieldValue.arrayUnion([registrationID]),
                    "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
    }
}
