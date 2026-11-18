//
//  PlaceGroupingView.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

import ComposableArchitecture
import SwiftUI
import UIKit

private func placeGroupingWindowBottomSafeAreaInset() -> CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .safeAreaInsets.bottom ?? 0
}

struct PlaceGroupingView: View {
    let store: StoreOf<PlaceGroupingFeature>
    @GestureState private var isSheetDragging = false
    @State private var sheetDragTranslation: CGFloat = 0
    @State private var sheetDetent: PlaceGroupingSheetLayout.Detent
    @State private var bottomSafeAreaInset = placeGroupingWindowBottomSafeAreaInset()
    @State private var confirmationGuideHeight: CGFloat = 16

    init(
        store: StoreOf<PlaceGroupingFeature>,
        initialSheetDetent: PlaceGroupingSheetLayout.Detent = .medium
    ) {
        self.store = store
        _sheetDetent = State(initialValue: initialSheetDetent)
    }

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

            GeometryReader { geometry in
                bottomSheet(
                    layout: PlaceGroupingSheetLayout(
                        availableHeight: geometry.size.height,
                        bottomSafeAreaInset: bottomSafeAreaInset,
                        confirmationGuideHeight: store.selectedTab == .recommendedGroups
                            ? confirmationGuideHeight : 0
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea(edges: .bottom)

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

            if store.isCriteriaChangeConfirmationPresented {
                DDAlertOverlay(
                    title: "이동 수단을 변경할까요?",
                    message: "변경하면 다시 분석해 추천 그룹이 달라져요.\n그래도 변경하시겠어요?",
                    cancelTitle: "아니요",
                    confirmTitle: "네",
                    onCancel: {
                        store.send(.criteriaChangeCancelTapped)
                    },
                    onConfirm: {
                        store.send(.criteriaChangeConfirmTapped)
                    }
                )
                .zIndex(7)
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: PlaceGroupingBottomSafeAreaInsetKey.self,
                    value: geometry.safeAreaInsets.bottom
                )
            }
        }
        .onPreferenceChange(PlaceGroupingBottomSafeAreaInsetKey.self) {
            bottomSafeAreaInset = max($0, placeGroupingWindowBottomSafeAreaInset())
        }
        .onChange(of: isSheetDragging) { _, isDragging in
            if !isDragging && sheetDragTranslation != 0 {
                withAnimation(.easeOut(duration: 0.22)) {
                    sheetDragTranslation = 0
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
            value: store.isCriteriaChangeConfirmationPresented
        )
        .overlay(alignment: .top) {
            if let notice = store.cancellationNotice {
                ConfirmationCancellationBanner(notice: notice)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.cancellationNotice)
        .task(id: store.cancellationNotice) {
            guard store.cancellationNotice != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            store.send(.cancellationNoticeDismissed)
        }
        .overlay {
            if store.isTransportationSheetPresented {
                transportationOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.22), value: store.isTransportationSheetPresented)
        .preferredColorScheme(.dark)
        .task {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    private var transportationOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.55)

                TripSetUpTransportationView(
                    store: store.scope(
                        state: \.transportationSheet,
                        action: \.transportationSheet
                    )
                )
                .frame(width: geometry.size.width + 2)
                .frame(height: TripSetUpTransportationView.sheetHeight, alignment: .top)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private var tripHeader: some View {
        DDNavigationHeader(
            accessibilityLabel: "예정된 여행으로 돌아가기",
            height: 51,
            onBack: { store.send(.backButtonTapped) }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.tripTitle)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)

                Text(store.tripDates)
                    .ddTypography(.label14)
                    .foregroundStyle(Color(red: 214 / 255, green: 214 / 255, blue: 214 / 255))
                    .frame(height: 20, alignment: .topLeading)
            }
            Spacer(minLength: 0)
        }
        .padding(.trailing, DDSpacing.small)
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

    private func bottomSheet(layout: PlaceGroupingSheetLayout) -> some View {
        let height = layout.height(for: sheetDetent, dragTranslation: sheetDragTranslation)

        return VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255))
                .frame(width: 142, height: 5)
                .padding(.top, 16)
                .padding(.bottom, 14)

            tabSelector
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, store.selectedTab == .recommendedGroups ? DDSpacing.small : 14)

            if store.selectedTab == .recommendedGroups {
                recommendedGroupSelectionHeader
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { height in
                        confirmationGuideHeight = height
                    }
            }

            Group {
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
            .opacity(height > layout.collapsedHeight ? 1 : 0)
            .allowsHitTesting(height > layout.collapsedHeight)
        }
        .frame(height: height, alignment: .top)
        .background(Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255))
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
        .ddBottomSheetBorder()
        .ddFillBottomSheetToScreenEdge(
            color: Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
        )
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .top) {
            Color.clear
                .contentShape(.rect)
                .frame(height: 35)
                .gesture(sheetDragGesture(layout: layout))
        }
    }

    private func sheetDragGesture(layout: PlaceGroupingSheetLayout) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($isSheetDragging) { _, isDragging, transaction in
                transaction.disablesAnimations = true
                isDragging = true
            }
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    sheetDragTranslation = value.translation.height
                }
            }
            .onEnded { value in
                let projectedHeight = layout.height(for: sheetDetent)
                    - value.predictedEndTranslation.height
                withAnimation(.easeOut(duration: 0.22)) {
                    sheetDetent = layout.nearestDetent(to: projectedHeight)
                    sheetDragTranslation = 0
                }
            }
    }

    private var tabSelector: some View {
        HStack(spacing: DDSpacing.xSmall) {
            tabButton("여행 취향", tab: .preferences)
            tabButton("추천 그룹", tab: .recommendedGroups)
        }
        .padding(DDSpacing.xSmall)
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
                        ? DDColor.actionSecondary
                        : Color.clear
                )
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var recommendedGroupSelectionHeader: some View {
        HStack(spacing: DDSpacing.xLarge) {
            Text("지역 그룹")
                .ddTypography(.heading18)
                .foregroundStyle(DDColor.textPrimary)

            Text("\(store.confirmedRecommendedGroupCount)/\(store.recommendedGroups.count) 선택")
                .ddTypography(.body16)
                .foregroundStyle(DDColor.textSecondary)

            Spacer(minLength: 0)

            Button {
                store.send(.selectAllRecommendedGroupsTapped)
            } label: {
                HStack(spacing: DDSpacing.small) {
                    ZStack {
                        Circle()
                            .fill(
                                store.haveAllRecommendedGroupsConfirmed
                                    ? DDColor.actionPrimary
                                    : DDColor.surfaceControl
                            )

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                store.haveAllRecommendedGroupsConfirmed
                                    ? DDColor.textOnPrimary
                                    : DDColor.textSecondary
                            )
                    }
                    .frame(width: 24, height: 24)

                    Text("전체 선택")
                        .ddTypography(.bodyEmphasis16)
                        .foregroundStyle(DDColor.textPrimary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.recommendedGroups.isEmpty)
        }
        .padding(.leading, DDSpacing.large)
        .padding(.trailing, 28)
        .frame(maxWidth: .infinity, minHeight: 52)
    }

    private func memberCard(_ member: PlaceGroupingFeature.Member) -> some View {
        Button {
            store.send(.memberTapped(member.id))
        } label: {
            HStack(spacing: DDSpacing.large) {
                DDMiniHeadAvatar(character: member.avatar, size: 40)

                VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
                    Text(member.name)
                        .ddTypography(.bodyEmphasis16)
                        .foregroundStyle(DDColor.textPrimary)

                    Text(member.preferences)
                        .ddTypography(.labelEmphasis14)
                        .foregroundStyle(DDColor.actionPrimary)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 19)
            .padding(.trailing, 20)
            .frame(height: 72)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255),
                        lineWidth: 1
                    )
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
            .padding(.horizontal, DDBottomActionLayout.horizontalInset)

            DDBottomActionArea(
                topSpacing: DDSpacing.small,
                bottomSafeAreaInset: bottomSafeAreaInset,
                backgroundColor: .clear
            ) {
                DDCTAButton(
                    title: "지역 그룹 확정하기",
                    isEnabled: store.hasConfirmedRecommendedGroup
                ) {
                    store.send(.confirmButtonTapped)
                }
            }
        }
    }
}

private struct PlaceGroupingBottomSafeAreaInsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("기본 높이") {
    PlaceGroupingView(store: placeGroupingPreviewStore(state: PlaceGroupingFeature.State()))
        .id("default-sheet-preview")
}

#Preview("추천 그룹 많음 · 드래그") {
    PlaceGroupingView(store: placeGroupingPreviewStore(state: PlaceGroupingPreviewData.manyGroupsState))
        .id("draggable-sheet-preview")
}

#Preview("추천 그룹 많음 · 전체") {
    PlaceGroupingView(
        store: placeGroupingPreviewStore(state: PlaceGroupingPreviewData.manyGroupsState),
        initialSheetDetent: .expanded
    )
    .id("expanded-sheet-preview")
}

#Preview("접힌 높이 · 확정 안내") {
    PlaceGroupingView(
        store: placeGroupingPreviewStore(state: PlaceGroupingPreviewData.manyGroupsState),
        initialSheetDetent: .collapsed
    )
    .id("collapsed-sheet-preview")
}

private func placeGroupingPreviewStore(state: PlaceGroupingFeature.State) -> StoreOf<PlaceGroupingFeature> {
    withDependencies {
        $0.placeClient = .testValue
    } operation: {
        Store(initialState: state) { PlaceGroupingFeature() }
    }
}
