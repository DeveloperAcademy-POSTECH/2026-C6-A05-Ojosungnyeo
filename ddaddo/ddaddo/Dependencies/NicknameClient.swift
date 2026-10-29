//
//  NicknameClient.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

enum NicknameClientError: Error, Equatable {
    case firebaseNotConfigured
    case duplicateNickname
    case networkUnavailable
    case saveFailed(code: Int, message: String)
}

struct NicknameClient: DependencyKey, Sendable {
    var hasNickname: @MainActor @Sendable (String) async throws -> Bool
    var saveNickname: @MainActor @Sendable (String, String) async throws -> Void
    var deleteProfile: @MainActor @Sendable (String) async throws -> Void

    static let liveValue = Self(
        hasNickname: { userID in
            try await FirebaseNicknameService.hasNickname(userID: userID)
        },
        saveNickname: { userID, nickname in
            try await FirebaseNicknameService.saveNickname(
                userID: userID,
                nickname: nickname
            )
        },
        deleteProfile: { userID in
            try await FirebaseNicknameService.deleteProfile(userID: userID)
        }
    )

    static let testValue = Self(
        hasNickname: { _ in false },
        saveNickname: { _, _ in },
        deleteProfile: { _ in }
    )
}

extension DependencyValues {
    var nicknameClient: NicknameClient {
        get { self[NicknameClient.self] }
        set { self[NicknameClient.self] = newValue }
    }
}
