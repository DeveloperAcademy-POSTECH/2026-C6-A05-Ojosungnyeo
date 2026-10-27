//
//  HomeView.swift
//  ddaddo
//
//  Created by sun on 10/19/26.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                DDColor.surfaceDefault
                    .ignoresSafeArea()

                header
                    .padding(.top, 32)

                speechBubble
                    .padding(.top, 137)

                Image("DDHomeMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 278, height: 365)
                    .padding(.top, 239)

                VStack(spacing: 0) {
                    Spacer()

                    tripCard
                        .padding(.horizontal, DDSpacing.large)
                        .padding(.bottom, 22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("어서오세따!")
                    .ddTypography(.title24)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(DDColor.textPrimary)

            Spacer()

            
            Button {
                store.send(.menuButtonTapped)
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 24, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("메뉴 열기")
        }
        .padding(.horizontal, DDSpacing.large)
    }

    private var speechBubble: some View {
        Text("저는 따또입니따.\n당신의 즐거운 지구 여행을 책임집니따.")
            .ddTypography(.bodyEmphasis16)
            .foregroundStyle(DDColor.textOnPrimary)
            .frame(width: 244, alignment: .leading)
            .frame(width: 324, height: 92)
            .background(.white)
            .clipShape(.rect(cornerRadius: 46))
            .overlay(alignment: .bottomTrailing) {
                Image("DDSpeechBubbleTail")
                    .resizable()
                    .frame(width: 27, height: 25)
                    .rotationEffect(.degrees(180))
                    .offset(x: -55, y: 17)
            }
    }

    private var tripCard: some View {
        DDColor.borderDefault
            .frame(height: 145)
            .overlay(alignment: .topLeading) {
                Image("DDHomeTripCardMascot")
                    .resizable()
                    .frame(maxWidth: .infinity)
                    .frame(height: 146)
            }
            .overlay {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: DDSpacing.xSmall) {
                        Image(systemName: "globe")
                        Text("Flight Ticket")
                            .ddTypography(.heading20)

                        Spacer()

                        Text("DDADDO")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color(red: 208 / 255, green: 208 / 255, blue: 208 / 255))
                    }

                    Spacer()

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
                            Text("EARTH")
                                .ddTypography(.title28)

                            Text("어디로 갈까요?")
                                .ddTypography(.body16)
                                .foregroundStyle(DDColor.textSecondary)
                        }

                        Spacer()

                        DDCTAButton(
                            title: "여행 추가하기",
                            layout: .compact,
                            action: { store.send(.addTripButtonTapped) }
                        )
                    }
                }
                .foregroundStyle(DDColor.textPrimary)
                .padding(.horizontal, DDSpacing.large)
                .padding(.vertical, 11)
            }
            .clipShape(.rect(cornerRadius: 20))
    }
}

#Preview {
    HomeView(
        store: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        }
    )
}
