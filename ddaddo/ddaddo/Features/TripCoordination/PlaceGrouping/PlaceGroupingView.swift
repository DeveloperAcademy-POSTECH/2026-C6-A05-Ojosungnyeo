//
//  PlaceGroupingView.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

import ComposableArchitecture
import SwiftUI

struct PlaceGroupingView: View {
    let store: StoreOf<PlaceGroupingFeature>

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(
                latitude: 35.6762,
                longitude: 139.7503,
                zoom: 12.2,
                placeGroups: store.placeGroups
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                tripHeader
                travelCriteria
                Spacer(minLength: 0)
            }

            bottomSheet

            if store.isDetailPresented {
                PlaceGroupingDetailView(
                    store: store.scope(
                        state: \.detail,
                        action: \.detail
                    ),
                    onBack: {
                        store.send(.detail(.backButtonTapped))
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }

            if store.isWaitingForConfirmationPresented {
                WaitingForConfirmationView(
                    store: store.scope(
                        state: \.waitingForConfirmation,
                        action: \.waitingForConfirmation
                    )
                )
                .transition(.move(edge: .trailing))
            }

            if store.isReanalyzing {
                LoadingView(message: "여행 취향과 장소를 다시 분석 중...")
                    .zIndex(5)
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !Task.isCancelled else { return }
                        store.send(.reanalysisFinished)
                    }
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: store.isWaitingForConfirmationPresented
        )
        .animation(
            .easeInOut(duration: 0.3),
            value: store.isDetailPresented
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: store.isReanalyzing
        )
        .sheet(
            isPresented: Binding(
                get: { store.isTransportationSheetPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.transportationSheetDismissed)
                    }
                }
            )
        ) {
            TripSetUpTransportationView(
                store: store.scope(
                    state: \.transportationSheet,
                    action: \.transportationSheet
                )
            )
            .presentationDetents([.height(524)])
            .presentationDragIndicator(.hidden)
        }
        .preferredColorScheme(.dark)
        .task {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    private var tripHeader: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Text(store.tripTitle)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)

                Text(store.tripDates)
                    .ddTypography(.label14)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 214 / 255, green: 214 / 255, blue: 214 / 255))
                    .frame(width: 200, height: 20, alignment: .top)
            }

            HStack {
                Button {
                    store.send(.backButtonTapped)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 25, weight: .regular))
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("예정된 여행으로 돌아가기")

                Spacer(minLength: 0)
            }
            .foregroundStyle(DDColor.textPrimary)
            .padding(.horizontal, DDSpacing.large)
        }
        .frame(height: 51, alignment: .top)
    }

    private var travelCriteria: some View {
        HStack(spacing: DDSpacing.small) {
            Text(store.travelCriteria)
                .ddTypography(.captionEmphasis12)
                .foregroundStyle(DDColor.textSecondary)

            Spacer(minLength: 0)

            Button("변경") {
                store.send(.travelCriteriaChangeTapped)
            }
            .ddTypography(.captionEmphasis12)
            .foregroundStyle(DDColor.textPrimary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 19)
        .frame(height: 40)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .padding(.horizontal, DDSpacing.large)
    }

    private var bottomSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255))
                .frame(width: 142, height: 5)
                .padding(.top, 16)
                .padding(.bottom, 17)

            tabSelector
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, 15)

            if store.selectedTab == .preferences {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.members) { member in
                            memberCard(member)
                        }
                    }
                    .padding(.horizontal, DDSpacing.large)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            } else {
                recommendedGroups
            }
        }
        .frame(height: 413, alignment: .top)
        .background(Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255))
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
        .ignoresSafeArea(edges: .bottom)
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("여행 취향", tab: .preferences)
            tabButton("추천 그룹", tab: .recommendedGroups)
        }
        .padding(3)
        .frame(height: 44)
        .background(DDColor.surfaceElevated)
        .clipShape(.capsule)
    }

    private func tabButton(_ title: String, tab: PlaceGroupingFeature.Tab) -> some View {
        Button {
            store.send(.tabSelected(tab))
        } label: {
            Text(title)
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(
                    store.selectedTab == tab
                        ? DDColor.actionPrimary
                        : DDColor.textSecondary
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    store.selectedTab == tab
                        ? Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255)
                        : Color.clear
                )
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private func memberCard(_ member: PlaceGroupingFeature.Member) -> some View {
        Button {
            store.send(.memberTapped(member.id))
        } label: {
            HStack(spacing: DDSpacing.large) {
                DDMiniHeadAvatar(character: member.avatar, size: 40)

                VStack(alignment: .leading, spacing: 0) {
                    Text(member.name)
                        .ddTypography(.bodyEmphasis16)
                        .foregroundStyle(DDColor.textPrimary)

                    Text(member.preferences)
                        .ddTypography(.labelEmphasis14)
                        .foregroundStyle(DDColor.actionPrimary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 19)
            .frame(height: 72)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DDColor.borderDefault, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var recommendedGroups: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.recommendedGroups) { group in
                        Button {
                            store.send(.recommendedGroupTapped(group.id))
                        } label: {
                            HStack(spacing: DDSpacing.large) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(group.title)
                                        .ddTypography(.bodyEmphasis16)

                                    Text(group.participantSummary)
                                        .ddTypography(.body16)
                                }
                                .foregroundStyle(DDColor.textPrimary)

                                Spacer(minLength: 0)

                                if store.confirmedGroupIDs.contains(group.id) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(DDColor.textOnPrimary)
                                        .frame(width: 24, height: 24)
                                        .background(DDColor.actionPrimary)
                                        .clipShape(.circle)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 24, weight: .regular))
                                        .foregroundStyle(DDColor.textPrimary)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .padding(.horizontal, 29)
                            .frame(maxWidth: .infinity, minHeight: 93, maxHeight: 93)
                            .background(DDColor.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 20))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(DDColor.borderDefault, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            DDCTAButton(
                title: "지역 그룹 확정하기",
                isEnabled: store.haveAllRecommendedGroupsConfirmed
            ) {
                store.send(.confirmButtonTapped)
            }
            .padding(.top, 8)
            .padding(.bottom, 34)
            .background(DDColor.surfaceDefault)
        }
        .padding(.horizontal, DDSpacing.large)
    }
}
#Preview {
    PlaceGroupingView(
        store: Store(initialState: PlaceGroupingFeature.State()) {
            PlaceGroupingFeature()
        }
    )
}
