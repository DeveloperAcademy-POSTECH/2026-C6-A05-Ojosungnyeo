//
//  FirebaseNicknameService.swift
//  ddaddo
//

import CryptoKit
import FirebaseFirestore
import Foundation

enum FirebaseNicknameService {
    private static let duplicateErrorDomain = "FirebaseNicknameService.Duplicate"

    static func hasNickname(userID: String) async throws -> Bool {
        guard FirebaseService.isConfigured else {
            throw NicknameClientError.firebaseNotConfigured
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .getDocument()
            return snapshot.get("nickname") as? String != nil
        } catch {
            throw map(error)
        }
    }

    static func saveNickname(userID: String, nickname: String) async throws {
        guard FirebaseService.isConfigured else {
            throw NicknameClientError.firebaseNotConfigured
        }

        let normalizedNickname = nickname
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let nicknameKey = SHA256.hash(data: Data(normalizedNickname.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        let database = Firestore.firestore()
        let nicknameReference = database.collection("nicknames").document(nicknameKey)
        let userReference = database.collection("users").document(userID)

        do {
            _ = try await database.runTransaction { transaction, errorPointer in
                do {
                    let nicknameDocument = try transaction.getDocument(nicknameReference)
                    if nicknameDocument.exists {
                        errorPointer?.pointee = NSError(
                            domain: duplicateErrorDomain,
                            code: 409
                        )
                        return nil
                    }

                    transaction.setData(
                        [
                            "uid": userID,
                            "nickname": nickname,
                            "normalizedNickname": normalizedNickname,
                            "createdAt": FieldValue.serverTimestamp()
                        ],
                        forDocument: nicknameReference
                    )
                    transaction.setData(
                        [
                            "nickname": nickname,
                            "nicknameKey": nicknameKey,
                            "updatedAt": FieldValue.serverTimestamp()
                        ],
                        forDocument: userReference,
                        merge: true
                    )
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        } catch let error as NSError where error.domain == duplicateErrorDomain {
            throw NicknameClientError.duplicateNickname
        } catch {
            throw map(error)
        }
    }

    private static func map(_ error: Error) -> NicknameClientError {
        let firebaseError = error as NSError
        if firebaseError.code == FirestoreErrorCode.unavailable.rawValue {
            return .networkUnavailable
        }
        return .saveFailed(
            code: firebaseError.code,
            message: firebaseError.localizedDescription
        )
    }
}
