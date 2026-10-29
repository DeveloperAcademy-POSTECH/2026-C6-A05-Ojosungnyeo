//
//  TripSetupOverviewView.swift
//  ddaddo
//

import SwiftUI

struct TripSetupOverviewView: View {
    let onBack: () -> Void
    let onRecommendationTapped: () -> Void

    init(
        onBack: @escaping () -> Void = {},
        onRecommendationTapped: @escaping () -> Void = {}
    ) {
        self.onBack = onBack
        self.onRecommendationTapped = onRecommendationTapped
    }

    var body: some View {
        VStack(spacing: DDSpacing.zero) {
            navigation

            VStack(alignment: .leading, spacing: DDSpacing.zero) {
                destinationHeader

                timer
                    .padding(.top, DDSpacing.medium)

                VStack(spacing: DDSpacing.medium) {
                    setupRow(title: "여행 일정", value: "11월 22일 ~ 25일 · 3박 4일")
                    setupRow(title: "여행 인원", value: "4명")
                    setupRow(title: "항공권 정보", value: "ICN ↔ NRT")
                    setupRow(title: "숙소 정보", value: "도쿄돔 호텔")
                }
                .padding(.top, DDSpacing.medium)

                joinedFriends
                    .padding(.top, 22)

                Spacer()

                DDCTAButton(
                    title: "취향 기반 여행 추천 보기",
                    action: onRecommendationTapped
                )
                    .padding(.bottom, 11)
            }
            .padding(.horizontal, DDSpacing.large)
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .foregroundStyle(DDColor.textPrimary)
    }

    private var navigation: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .regular))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(height: 43)
        .padding(.horizontal, DDSpacing.large)
    }

    private var destinationHeader: some View {
        HStack(spacing: DDSpacing.small) {
            VStack(alignment: .leading, spacing: 1) {
                Text("도쿄 여행")
                    .ddTypography(.heading20)
                Text("일본 · 1개 도시")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
            }

            Spacer()

            Text("여행지 변경")
                .ddTypography(.captionEmphasis12)
                .frame(width: 108, height: 36)
                .background(DDColor.surfaceElevated)
                .clipShape(.rect(cornerRadius: DDSpacing.medium))
        }
        .frame(height: 65)
    }

    private var timer: some View {
        Label("00:00:00", systemImage: "timer")
            .ddTypography(.captionEmphasis12)
            .foregroundStyle(DDColor.textSecondary)
            .frame(height: 19)
    }

    private func setupRow(title: String, value: String) -> some View {
        HStack(spacing: DDSpacing.small) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .ddTypography(.heading18)
                Text(value)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .regular))
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 69)
        .background(DDColor.surfaceElevated)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 0.5)
        }
        .clipShape(.rect(cornerRadius: 20))
    }

    private var joinedFriends: some View {
        HStack(spacing: DDSpacing.medium) {
            HStack(spacing: 5) {
                setupAvatar(character: .tae)
                setupAvatar(character: .header)
                setupAvatar(character: .grae)
                setupAvatar(character: .juni)
            }

            Text("4명 참여 중")
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)
        }
    }

    private func setupAvatar(character: DDMiniHeadAvatar.Character) -> some View {
        ZStack {
            Circle()
                .fill(avatarBackground(for: character))

            Image(character.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: 35, height: 30)
        }
        .frame(width: 40, height: 40)
    }

    private func avatarBackground(for character: DDMiniHeadAvatar.Character) -> Color {
        switch character {
        case .tae:
            Color(red: 217 / 255, green: 149 / 255, blue: 126 / 255)
        case .header:
            Color(red: 152 / 255, green: 156 / 255, blue: 209 / 255)
        case .grae:
            Color(red: 102 / 255, green: 181 / 255, blue: 173 / 255)
        case .juni:
            Color(red: 197 / 255, green: 143 / 255, blue: 167 / 255)
        }
    }
}

#Preview("TripSetUpView_AddTravel_6") {
    TripSetupOverviewView()
}
