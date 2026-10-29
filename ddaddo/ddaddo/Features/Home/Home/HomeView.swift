//
//  HomeView.swift
//  ddaddo
//
//  Created by sun on 10/19/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / Layout.designWidth,
                proxy.size.height / Layout.designHeight
            )

            ZStack(alignment: .topLeading) {
                DDColor.surfaceDefault

                moonSurface
                mascot
                sparkles
                bottomGradient
                speechBubble
                menuButton
                exploreTripsButton

                if store.isMenuPresented {
                    menuDismissArea
                    accountMenu
                }
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
        .confirmationDialog(
            "정말 탈퇴할까요?",
            isPresented: Binding(
                get: { store.isWithdrawalConfirmationPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.withdrawalConfirmationDismissed)
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("탈퇴하기", role: .destructive) {
                store.send(.withdrawalConfirmed)
            }
            Button("취소", role: .cancel) {
                store.send(.withdrawalConfirmationDismissed)
            }
        } message: {
            Text("계정을 삭제하면 다시 되돌릴 수 없어요.")
        }
        .alert(
            "탈퇴할 수 없어요",
            isPresented: Binding(
                get: { store.withdrawalErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.withdrawalErrorDismissed)
                    }
                }
            )
        ) {
            Button("확인") {
                store.send(.withdrawalErrorDismissed)
            }
        } message: {
            Text(store.withdrawalErrorMessage ?? "")
        }
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
        Button {
            store.send(.mascotTapped)
        } label: {
            Image("DDMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 278, height: 365)
                .contentShape(Rectangle())
        }
        .buttonStyle(NoPressEffectButtonStyle())
        .position(x: 201, y: 480.5)
        .accessibilityLabel("따또 메시지 바꾸기")
    }

    private var speechBubble: some View {
        Text(store.mascotMessage.text)
            .ddTypography(.bodyEmphasis16)
            .foregroundStyle(DDColor.textOnPrimary)
            .lineSpacing(4)
            .frame(width: 241, alignment: .leading)
            .frame(width: 324, height: 92)
            .background(.white)
            .clipShape(.rect(cornerRadius: 46))
            .overlay(alignment: .bottomTrailing) {
                Image("DDSpeechBubbleTail")
                    .resizable()
                    .frame(width: 27.0645, height: 24.5)
                    .rotationEffect(.degrees(180))
                    .offset(x: -54, y: 17)
            }
            .position(x: 203, y: 242)
    }

    private var sparkles: some View {
        ZStack {
            sparkle(size: 29, x: 66.5, y: 397)
            sparkle(size: 24, x: 299, y: 568)
            sparkle(size: 39, x: 334.5, y: 389)
            sparkle(size: 28, x: 80, y: 552)
            sparkle(size: 20, x: 345, y: 524)
        }
        .frame(width: Layout.designWidth, height: Layout.designHeight)
        .foregroundStyle(DDColor.actionPrimary)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func sparkle(size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .semibold))
            .position(x: x, y: y)
    }

    private var bottomGradient: some View {
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
        .allowsHitTesting(false)
    }

    private var menuButton: some View {
        Button {
            store.send(.menuButtonTapped)
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: 370, y: 78)
        .accessibilityLabel("메뉴 열기")
    }

    private var menuDismissArea: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: Layout.designWidth, height: Layout.designHeight)
            .onTapGesture {
                store.send(.menuDismissed)
            }
    }

    private var accountMenu: some View {
        VStack(spacing: 0) {
            accountMenuButton("로그아웃") {
                store.send(.logoutButtonTapped)
            }

            Rectangle()
                .fill(Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255))
                .frame(height: 1)

            accountMenuButton("탈퇴하기") {
                store.send(.withdrawButtonTapped)
            }
            .disabled(store.isWithdrawing)
        }
        .frame(width: 133)
        .background(Color.black)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255),
                    lineWidth: 1
                )
        }
        .position(x: 321.5, y: 100)
        .accessibilityElement(children: .contain)
    }

    private func accountMenuButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, DDSpacing.large)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var exploreTripsButton: some View {
        Button {
            store.send(.exploreTripsButtonTapped)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "chevron.down.dotted.2")
                    .font(.system(size: 16, weight: .semibold))
                    .rotationEffect(.degrees(180))

                Text("여행 찾아보기")
                    .ddTypography(.heading20)
            }
            .foregroundStyle(.white)
            .frame(width: 346, height: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: 201, y: 766)
    }

    private enum Layout {
        static let designWidth: CGFloat = 402
        static let designHeight: CGFloat = 874
    }
}

private struct NoPressEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

#Preview {
    HomeView(
        store: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        }
    )
}
