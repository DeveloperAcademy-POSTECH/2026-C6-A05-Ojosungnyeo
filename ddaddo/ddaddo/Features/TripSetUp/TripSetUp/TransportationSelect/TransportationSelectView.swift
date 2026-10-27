//
//  TransportationSelectView.swift
//  ddaddo
//
//  Created by sun on 10/23/26.
//

import ComposableArchitecture
import SwiftUI

struct TransportationSelectView: View {
    let store: StoreOf<TransportationSelectFeature>

    var body: some View {
        VStack(spacing: 0) {
            tripNavigation

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heading
                    transportationSection
                    durationSection
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.large)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAction
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var tripNavigation: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Text("도쿄 여행")
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(DDColor.textPrimary)

                Text("11월 22일 ~ 25일")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
            }

            HStack {
                Button {
                    store.send(.backButtonTapped)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 25, weight: .regular))
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(.rect)
                }

                Spacer()
            }
            .foregroundStyle(DDColor.textPrimary)
            .padding(.horizontal, DDSpacing.large)
        }
        .frame(height: 51, alignment: .top)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: DDSpacing.small) {
            HStack(spacing: DDSpacing.xSmall) {
                Text("이동 기준을 알려주세따")
                    .ddTypography(.title24)
                    .foregroundStyle(DDColor.textPrimary)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DDColor.textPrimary)
            }

            Text("이 정보를 바탕으로 가까운 장소를 묶고,\n함께 여행할 그룹을 제안해 드려요.")
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(.top, 10)
    }

    private var transportationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            requiredTitle("이동수단")

            Text("이번 여행에서 주로 이용할 수단을 선택해 주세요.")
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
                .padding(.top, DDSpacing.small)

            HStack(spacing: DDSpacing.medium) {
                ForEach(Transportation.allCases) { transportation in
                    TransportationChoiceCard(
                        transportation: transportation,
                        isSelected: store.selectedTransportation == transportation
                    ) {
                        store.send(.transportationSelected(transportation))
                    }
                }
            }
            .padding(.top, DDSpacing.medium)
        }
        .padding(.top, 58)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            requiredTitle("장소 간 최대 이동시간")

            Text("한 장소에서 다음 장소까지 이동하는 기준이에요.")
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
                .padding(.top, DDSpacing.small)

            HStack(spacing: 10) {
                ForEach(TravelDuration.allCases) { duration in
                    Button {
                        store.send(.durationSelected(duration))
                    } label: {
                        Text(duration.title)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(
                                store.selectedDuration == duration
                                    ? DDColor.textOnPrimary
                                    : DDColor.textPrimary
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                store.selectedDuration == duration
                                    ? DDColor.actionPrimary
                                    : DDColor.surfaceElevated
                            )
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, DDSpacing.medium)

            if let durationDescription {
                Text(durationDescription)
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
                    .padding(.top, DDSpacing.small)
            }
        }
        .padding(.top, DDSpacing.xLarge)
    }

    private var durationDescription: String? {
        guard
            let transportation = store.selectedTransportation,
            let duration = store.selectedDuration
        else { return nil }

        return "\(transportation.title)으로 최대 \(duration.rawValue)분 이내에 이동할 수 있는 장소를 묶어요."
    }

    private var bottomAction: some View {
        VStack(spacing: DDSpacing.large) {
            HStack(spacing: 10) {
                Image("DDTransportationInfo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

                Text("먼저 선택한 멤버의 기준으로 그룹을 만들어요.\n그룹 편집 전까지 이동 기준을 바꿀 수 있어요.")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DDSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 12))

            DDCTAButton(
                title: "이 기준으로 그룹핑 보여주기",
                isEnabled: store.isSelectionComplete
            ) {
                store.send(.recommendationButtonTapped)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, DDSpacing.large)
        .padding(.bottom, 11)
        .background(DDColor.surfaceDefault)
    }

    private func requiredTitle(_ title: String) -> some View {
        HStack(spacing: DDSpacing.xSmall) {
            Text(title)
                .ddTypography(.bodyEmphasis16)

            Text("*")
                .ddTypography(.labelEmphasis14)
        }
        .foregroundStyle(DDColor.textPrimary)
    }
}

#Preview {
    TransportationSelectView(
        store: Store(initialState: TransportationSelectFeature.State()) {
            TransportationSelectFeature()
        }
    )
}
