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
            let database = Firestore.firestore()
            let snapshot = try await database
                .collection("users")
                .document(userID)
                .getDocument()
            if let nickname = snapshot.get("nickname") as? String,
               !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }

            // 기존 데이터가 닉네임 인덱스에만 남아 있는 경우에도 같은 Firebase UID로 찾는다.
            let nicknameSnapshot = try await database
                .collection("nicknames")
                .whereField("uid", isEqualTo: userID)
                .limit(to: 1)
                .getDocuments()
            return !nicknameSnapshot.documents.isEmpty
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
                    if nicknameDocument.exists,
                       nicknameDocument.get("uid") as? String != userID {
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

    static func deleteProfile(userID: String) async throws {
        guard FirebaseService.isConfigured else {
            throw NicknameClientError.firebaseNotConfigured
        }

        let database = Firestore.firestore()
        let userReference = database.collection("users").document(userID)

        do {
            let userDocument = try await userReference.getDocument()
            let ownedNicknameDocuments = try await database
                .collection("nicknames")
                .whereField("uid", isEqualTo: userID)
                .getDocuments()
            let batch = database.batch()
            var nicknameReferences = Dictionary(
                uniqueKeysWithValues: ownedNicknameDocuments.documents.map {
                    ($0.reference.path, $0.reference)
                }
            )

            if let nicknameKey = userDocument.get("nicknameKey") as? String {
                let nicknameReference = database
                    .collection("nicknames")
                    .document(nicknameKey)
                nicknameReferences[nicknameReference.path] = nicknameReference
            }

            for nicknameReference in nicknameReferences.values {
                batch.deleteDocument(nicknameReference)
            }

            batch.deleteDocument(userReference)
            try await batch.commit()
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
