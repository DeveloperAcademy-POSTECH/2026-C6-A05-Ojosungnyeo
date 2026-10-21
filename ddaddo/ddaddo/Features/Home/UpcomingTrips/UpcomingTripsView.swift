//
//  UpcomingTripsView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct UpcomingTripsView: View {
    let store: StoreOf<UpcomingTripsFeature>

    var body: some View {
        ZStack {
            DDColor.surfaceDefault
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: DDSpacing.large) {
                    ForEach(store.trips) { trip in
                        UpcomingTripCard(
                            trip: trip,
                            viewScheduleAction: {
                                store.send(.viewScheduleButtonTapped(trip.id))
                            },
                            inviteAction: {
                                store.send(.inviteButtonTapped(trip.id))
                            }
                        )
                    }
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.top, 32)
                .padding(.bottom, DDSpacing.xLarge)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .padding(.horizontal, DDSpacing.large)
                    .padding(.bottom, DDSpacing.xLarge)
                    .background(DDColor.surfaceDefault)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: DDSpacing.small) {
            HStack(spacing: DDSpacing.xSmall) {
                Text("예정된 여행이 이따")
                    .ddTypography(.title24)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 21, weight: .semibold))
            }
            .foregroundStyle(DDColor.textPrimary)

            Spacer(minLength: DDSpacing.small)

            HStack(spacing: 2) {
                headerButton(
                    systemName: "plus",
                    accessibilityLabel: "여행 추가",
                    action: { store.send(.addTripButtonTapped) }
                )

                headerButton(
                    systemName: "bell",
                    accessibilityLabel: "알림",
                    action: { store.send(.notificationButtonTapped) }
                )
            }
        }
        .frame(height: 44)
    }

    private func headerButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(DDColor.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct UpcomingTripCard: View {
    let trip: UpcomingTripsFeature.Trip
    let viewScheduleAction: () -> Void
    let inviteAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image(trip.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 193)
                    .clipped()

                DDColor.surfaceControl
                    .opacity(0.82)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.destination)
                        .ddTypography(.heading18)
                        .foregroundStyle(DDColor.textPrimary)

                    Text("\(trip.dateText) · \(trip.participantCount)명")
                        .ddTypography(.body16)
                        .foregroundStyle(DDColor.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .frame(height: 193)

            HStack(spacing: 0) {
                cardButton(title: "일정 보기", action: viewScheduleAction)

                Rectangle()
                    .fill(DDColor.textPrimary)
                    .frame(width: 1)

                cardButton(title: "초대하기", action: inviteAction)
            }
            .frame(height: 53)
            .background(DDColor.surfaceElevated)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DDColor.textPrimary)
                    .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 246)
        .background(DDColor.surfaceControl)
        .clipShape(.rect(cornerRadius: 20))
    }

    private func cardButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UpcomingTripsView(
        store: Store(initialState: UpcomingTripsPreviewData.state) {
            UpcomingTripsFeature()
        }
    )
}
