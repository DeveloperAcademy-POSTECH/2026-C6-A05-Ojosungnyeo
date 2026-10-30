//
//  NicknameSetupView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct NicknameSetupView: View {
    let store: StoreOf<NicknameSetupFeature>

    @FocusState private var isNicknameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(spacing: 0) {
                nicknameAvatar

                nicknameForm
                    .padding(.top, 12)
            }
            .padding(.top, 48)

            Spacer(minLength: 24)

            continueButton
                .padding(.bottom, 38)
        }
        .padding(.horizontal, 24)
        .padding(.top, 63)
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onTapGesture {
            isNicknameFieldFocused = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("반가워요, 지구 여행자님")
                .ddTypography(.eyebrow13)
                .foregroundStyle(DDColor.actionPrimary)

            Text("어떻게 불러드릴까요?")
                .ddTypography(.title26)
                .foregroundStyle(DDColor.textPrimary)

            Text("친구들에게 보여줄 닉네임을 알려주세요.")
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nicknameForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("닉네임")
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textTertiary)

            HStack(spacing: 12) {
                TextField(
                    "닉네임을 입력해 주세요.",
                    text: Binding(
                        get: { store.nickname },
                        set: { store.send(.nicknameChanged($0)) }
                    )
                )
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(inputForegroundColor)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isNicknameFieldFocused)
                .onSubmit {
                    store.send(.continueButtonTapped)
                }

                Text("\(store.nickname.count)/10")
                    .ddTypography(.caption12)
                    .foregroundStyle(Color(red: 136 / 255, green: 136 / 255, blue: 136 / 255))
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(inputBorderColor, lineWidth: 1)
            }

            Text(store.errorMessage ?? "2~10자로 입력해 주세요.")
                .ddTypography(.caption12)
                .foregroundStyle(store.errorMessage == nil ? DDColor.textSecondary : DDColor.statusError)
                .frame(height: 40, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nicknameAvatar: some View {
        Image("DDNicknameSetupMascot")
            .resizable()
            .scaledToFit()
            .frame(width: 144, height: 170)
            .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var continueButton: some View {
        Button {
            isNicknameFieldFocused = false
            store.send(.continueButtonTapped)
        } label: {
            ZStack {
                Text("시작하기")
                    .ddTypography(.bodyEmphasis16)

                if store.isSubmitting {
                    ProgressView()
                        .tint(DDColor.textOnPrimary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 18)
                }
            }
            .foregroundStyle(DDColor.textOnPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(store.isContinueEnabled ? DDColor.actionPrimary : DDColor.actionSecondary)
            .clipShape(.rect(cornerRadius: 20))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!store.isContinueEnabled)
    }

    private var inputBorderColor: Color {
        if store.errorMessage != nil {
            DDColor.statusError
        } else if !store.nickname.isEmpty {
            DDColor.actionPrimary
        } else {
            DDColor.borderDefault
        }
    }

    private var inputForegroundColor: Color {
        store.errorMessage == nil ? DDColor.textPrimary : DDColor.statusError
    }
}

#Preview {
    NicknameSetupView(
        store: Store(
            initialState: NicknameSetupFeature.State(
                userID: "preview",
                nickname: "지구인"
            )
        ) {
            NicknameSetupFeature()
        }
    )
}
