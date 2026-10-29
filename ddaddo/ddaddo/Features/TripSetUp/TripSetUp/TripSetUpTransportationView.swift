//
//  TripSetUpTransportationView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct TripSetUpTransportationView: View {
    let store: StoreOf<TripSetUpTransportationFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, DDSpacing.medium)

            HStack {
                Button {
                    store.send(.closeButtonTapped)
                } label: {
                    Image(systemName: "x.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DDColor.actionSecondary)
                }
                .accessibilityLabel("닫기")

                Spacer()

                Button {
                    store.send(.confirmButtonTapped)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DDColor.actionPrimary)
                }
                .accessibilityLabel("완료")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DDSpacing.xLarge)
            .padding(.top, DDSpacing.medium)

            VStack(alignment: .leading, spacing: 0) {
                Text("이동수단")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)

                Text("이번 여행에서 주로 이용할 수단을 선택해 주세요.")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
                    .padding(.top, DDSpacing.small)

                HStack(spacing: DDSpacing.medium) {
                    ForEach(Transportation.allCases) { transportation in
                        transportationCard(transportation)
                    }
                }
                .padding(.top, DDSpacing.medium)

                Text("장소 간 최대 이동시간")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.top, 28)

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
                                .clipShape(.capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, DDSpacing.medium)

                Text("\(store.selectedTransportation.title)으로 최대 \(store.selectedDuration.rawValue)분 이내에 이동할 수 있는 장소를 묶어요.")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
                    .padding(.top, DDSpacing.small)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 28)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DDColor.surfaceDefault)
        .preferredColorScheme(.dark)
    }

    private func transportationCard(_ transportation: Transportation) -> some View {
        let isSelected = store.selectedTransportation == transportation

        return Button {
            store.send(.transportationSelected(transportation))
        } label: {
            VStack(spacing: DDSpacing.small) {
                Image(transportation.imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isSelected ? DDColor.actionPrimary : DDColor.textPrimary)
                    .frame(width: 26, height: 26)

                Text(transportation.title)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(isSelected ? DDColor.actionPrimary : DDColor.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? DDColor.actionPrimary : DDColor.actionSecondary, lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Circle()
                        .fill(DDColor.actionPrimary)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Image("DDTransportationCheck")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                        }
                        .padding(9)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    TripSetUpTransportationView(
        store: Store(initialState: TripSetUpTransportationFeature.State()) {
            TripSetUpTransportationFeature()
        }
    )
    .frame(height: 524)
}
