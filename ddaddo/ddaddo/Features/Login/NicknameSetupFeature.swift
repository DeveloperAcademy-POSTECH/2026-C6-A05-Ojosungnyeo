//
//  NicknameSetupFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct NicknameSetupFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var userID = ""
        var nickname = ""
        var isSubmitting = false
        var errorMessage: String?

        var trimmedNickname: String {
            nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var isContinueEnabled: Bool {
            (2...10).contains(trimmedNickname.count) && !isSubmitting
        }
    }

    enum Action {
        case nicknameChanged(String)
        case continueButtonTapped
        case saveResponse(Result<Void, Error>)
        case delegate(Delegate)

        enum Delegate {
            case completed
        }
    }

    @Dependency(\.nicknameClient) var nicknameClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .nicknameChanged(nickname):
                state.nickname = String(nickname.prefix(10))
                state.errorMessage = nil
                return .none

            case .continueButtonTapped:
                guard state.isContinueEnabled else { return .none }
                let userID = state.userID
                let nickname = state.trimmedNickname
                state.isSubmitting = true
                state.errorMessage = nil

                return .run { send in
                    await send(
                        .saveResponse(
                            Result {
                                try await nicknameClient.saveNickname(userID, nickname)
                            }
                        )
                    )
                }

            case .saveResponse(.success):
                state.isSubmitting = false
                return .send(.delegate(.completed))

            case let .saveResponse(.failure(error)):
                state.isSubmitting = false
                switch error as? NicknameClientError {
                case .duplicateNickname:
                    state.errorMessage = "중복된 닉네임입니다. 다른 닉네임을 입력해 주세요."
                case .firebaseNotConfigured:
                    state.errorMessage = "Firebase 설정을 확인해 주세요."
                case .networkUnavailable:
                    state.errorMessage = "네트워크 연결을 확인해 주세요."
                case .saveFailed, nil:
                    state.errorMessage = "닉네임을 저장하지 못했어요. 다시 시도해 주세요."
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
