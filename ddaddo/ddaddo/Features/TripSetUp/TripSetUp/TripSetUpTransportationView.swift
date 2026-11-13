//
//  TripSetUpTransportationView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct TripSetUpTransportationView: View {
    static let sheetHeight = TripDatePickerView.sheetHeight

    let store: StoreOf<TripSetUpTransportationFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 140, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, DDSpacing.medium)

            HStack {
                Button {
                    store.send(.closeButtonTapped)
                } label: {
                    Image(systemName: "x.circle.fill")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(DDColor.borderDefault)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("닫기")

                Spacer()

                Button {
                    store.send(.confirmButtonTapped)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(DDColor.actionPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("완료")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, DDSpacing.small)
            .padding(.bottom, DDSpacing.large)

            VStack(alignment: .leading, spacing: 0) {
                Text("이동수단")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(height: 24, alignment: .leading)

                Text("이번 여행에서 주로 이용할 수단을 선택해 주세요.")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
                    .frame(minHeight: 16, alignment: .leading)
                    .padding(.top, DDSpacing.small)

                HStack(spacing: DDSpacing.medium) {
                    ForEach(Transportation.allCases) { transportation in
                        transportationCard(transportation)
                    }
                }
                .padding(.top, 10)

                Text("장소 간 최대 이동시간")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(height: 24, alignment: .leading)
                    .padding(.top, DDSpacing.xLarge)

                Text("한 장소에서 다음 장소까지 이동하는 기준이에요.")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
                    .frame(minHeight: 16, alignment: .leading)
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
                .padding(.top, 10)

                Text("\(store.selectedTransportation.title)\(store.selectedTransportation.title == "자동차" ? "로" : "으로") 최대 \(store.selectedDuration.rawValue)분 이내에 이동할 수 있는 장소를 묶어요.")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
                    .frame(minHeight: 16, alignment: .leading)
                    .padding(.top, DDSpacing.small)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, DDSpacing.small)

            Spacer(minLength: 0)
        }
        .frame(height: Self.sheetHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DDColor.surfaceDefault)
        .clipShape(
            .rect(
                topLeadingRadius: 40,
                topTrailingRadius: 40
            )
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40
            )
            .strokeBorder(
                Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255),
                lineWidth: 1
            )
            .frame(height: Self.sheetHeight + 120)
            .allowsHitTesting(false)
        }
        .ddFillBottomSheetToScreenEdge()
        .ignoresSafeArea(edges: .bottom)
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
                    .frame(height: 24)
            }
            .padding(.top, 18)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .top)
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

#Preview("이동수단 시트") {
    GeometryReader { geometry in
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)

            TripSetUpTransportationView(
                store: Store(initialState: TripSetUpTransportationFeature.State()) {
                    TripSetUpTransportationFeature()
                }
            )
            .frame(width: geometry.size.width + 2)
            .frame(height: TripSetUpTransportationView.sheetHeight, alignment: .top)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .ignoresSafeArea()
}
