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
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / Layout.designWidth,
                proxy.size.height / Layout.designHeight
            )

            ZStack(alignment: .topLeading) {
                Color.black

                moonSurface
                mascot

                LinearGradient(
                    colors: [
                        Color(red: 168 / 255, green: 165 / 255, blue: 164 / 255)
                            .opacity(0.3),
                        Color.black.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: Layout.designWidth, height: 178)
                .offset(y: 696)

                Image("DDLoginLogo")
                    .resizable()
                    .frame(width: 176, height: 145)
                    .offset(x: 113, y: 119)
                    .accessibilityHidden(true)

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .ddTypography(.label14)
                        .foregroundStyle(DDColor.statusCritical)
                        .multilineTextAlignment(.center)
                        .frame(width: 342)
                        .offset(x: 30, y: 700)
                }

                ZStack {
                    AppleSignInButton {
                        store.send(.appleSignInButtonTapped)
                    }
                    .opacity(store.isSigningIn ? 0.55 : 1)

                    if store.isSigningIn {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(width: 342, height: 54)
                .disabled(store.isSigningIn)
                .accessibilityLabel("Apple로 로그인")
                .offset(x: 30, y: 732)
            }
            .frame(width: Layout.designWidth, height: Layout.designHeight)
            .scaleEffect(scale, anchor: .top)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
            .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private var moonSurface: some View {
        Image("DDLoginMoon")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 788.417, height: 539.306)
            .clipped()
            .rotationEffect(.degrees(-10.09))
            .position(x: 160.359, y: 731.555)
            .accessibilityHidden(true)
    }

    private var mascot: some View {
        Image("DDLoginMascot")
            .resizable()
            .frame(width: 278, height: 431)
            .offset(y: -48)
            .frame(width: 278, height: 365, alignment: .top)
            .clipped()
            .position(x: 201, y: 480.5)
            .accessibilityHidden(true)
    }

    private enum Layout {
        static let designWidth: CGFloat = 402
        static let designHeight: CGFloat = 874
    }
}

private struct AppleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signUp,
            authorizationButtonStyle: .black
        )
        button.cornerRadius = 14
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
