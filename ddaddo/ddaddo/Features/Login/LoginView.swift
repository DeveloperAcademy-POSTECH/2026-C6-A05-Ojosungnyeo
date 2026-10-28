//
//  LoginView.swift
//  ddaddo
//
//  Created by sun on 10/28/26.
//

import AuthenticationServices
import ComposableArchitecture
import SwiftUI

struct LoginView: View {
    let store: StoreOf<LoginFeature>

    var body: some View {
        ZStack {
            DDColor.surfaceDefault
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("DDHomeMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .accessibilityHidden(true)

                Text("따로 또 같이,")
                    .ddTypography(.title28)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.top, DDSpacing.xLarge)

                Text("따또와 함께 여행을 시작해요")
                    .ddTypography(.body16)
                    .foregroundStyle(DDColor.textSecondary)
                    .padding(.top, DDSpacing.small)

                Spacer()

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .ddTypography(.label14)
                        .foregroundStyle(DDColor.statusCritical)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, DDSpacing.medium)
                }

                ZStack {
                    AppleSignInButton {
                        store.send(.appleSignInButtonTapped)
                    }
                    .opacity(store.isSigningIn ? 0.45 : 1)

                    if store.isSigningIn {
                        ProgressView()
                            .tint(.black)
                    }
                }
                .frame(height: 55)
                .disabled(store.isSigningIn)
                .accessibilityLabel("Apple로 로그인")
                .padding(.horizontal, DDSpacing.xLarge)
                .padding(.bottom, DDSpacing.xLarge)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct AppleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .white
        )
        button.cornerRadius = DDRadius.medium
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.buttonTapped),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func buttonTapped() {
            action()
        }
    }
}

#Preview {
    LoginView(
        store: Store(initialState: LoginFeature.State()) {
            LoginFeature()
        }
    )
}
