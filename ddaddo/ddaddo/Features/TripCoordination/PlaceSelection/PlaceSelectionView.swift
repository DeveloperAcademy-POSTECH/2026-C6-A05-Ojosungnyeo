//
//  PlaceSelectionView.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture
import SwiftUI
import UIKit

private func activeWindowBottomSafeAreaInset() -> CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .safeAreaInsets.bottom ?? 0
}

struct PlaceSelectionView: View {
    let store: StoreOf<PlaceSelectionFeature>
    @GestureState private var sheetDragTranslation: CGFloat = 0
    @State private var bottomSafeAreaInset = activeWindowBottomSafeAreaInset()

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(
                selectedPlace: store.isPlaceDetailsLoading
                    && store.selectedPinnedPlace == nil
                    ? nil
                    : store.selectedPlace,
                showsSelectedPlaceMarker: store.selectedPinnedPlace == nil,
                pinnedPlaces: store.mapPlaces,
                showsPinnedPlaceNumbers: false,
                onPinnedPlaceTapped: { place in
                    store.send(.pinnedPlaceTapped(place))
                }
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar
                if !store.isShowingConfirmedPlaces {
                    searchField
                }
                Spacer()
            }

            if store.isBottomSheetExpanded
                && store.selectedPlace == nil
                && !store.isMemberPlacesSheetPresented
                && store.displayedPlaces.isEmpty {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.send(.dimmedBackgroundTapped)
                    }

            }

            if store.isShowingConfirmedPlaces
                && !store.isMemberPlacesSheetPresented
                && store.selectedPlace == nil {
                ConfirmedPlacesBottomSheet(
                    participants: store.participants,
                    places: store.confirmedPlaces,
                    canCancelConfirmation: store.canCancelPlaceConfirmation,
                    bottomSafeAreaInset: bottomSafeAreaInset,
                    memberTapped: { member in
                        store.send(.memberProfileTapped(member))
                    },
                    confirmationButtonTapped: {
                        store.send(.confirmButtonTapped)
                    }
                )
                .frame(height: 379 + bottomSafeAreaInset, alignment: .top)
                .clipped()
                .ignoresSafeArea(edges: .bottom)
            } else if let selectedPlace = store.selectedPlace {
                SelectedPlaceBottomSheet(
                    place: selectedPlace,
                    isLoading: store.isPlaceDetailsLoading,
                    canAdd: store.canAddSelectedPlace,
                    isAlreadyAdded: store.isSelectedPlaceAlreadyAdded,
                    fallbackImageName: store.selectedPinnedPlace?.thumbnailName,
                    bottomSafeAreaInset: bottomSafeAreaInset,
                    closeButtonTapped: {
                        store.send(.selectedPlaceCloseButtonTapped)
                    },
                    addButtonTapped: {
                        store.send(.addSelectedPlaceButtonTapped)
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            } else if store.isMemberPlacesSheetPresented {
                MemberPlacesBottomSheet(
                    isExpanded: store.isBottomSheetExpanded,
                    selectedMember: store.selectedMember,
                    participants: store.participants,
                    places: store.displayedPlaces,
                    canDeletePlaces: store.canEditDisplayedPlaces,
                    canConfirm: store.canConfirmPlaceSelection,
                    canCancelConfirmation: store.canCancelPlaceConfirmation,
                    showsConfirmationButton: store.isViewingCurrentUser,
                    isConfirmationComplete: store.isCurrentUserConfirmed,
                    bottomContentInset: store.hasSelectionEnded ? 124 : DDSpacing.xLarge
                ) { member in
                    store.send(.memberProfileTapped(member))
                } placeTapped: { place in
                    store.send(.pinnedPlaceTapped(place))
                } deletePlace: { place in
                    store.send(.deletePinnedPlaceButtonTapped(place.id))
                } movePlace: { sourceID, targetID in
                    store.send(.movePinnedPlace(sourceID: sourceID, beforeID: targetID))
                } confirmButtonTapped: {
                    store.send(.confirmButtonTapped)
                }
                .frame(height: currentMemberSheetHeight, alignment: .top)
                .clipped()
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Color.clear
                        .contentShape(.rect)
                        .frame(height: 44)
                        .gesture(sheetDragGesture)
                }
            } else {
                PlaceSelectionBottomSheet(
                    isExpanded: store.isBottomSheetExpanded,
                    selectedMember: store.selectedMember,
                    participants: store.participants,
                    destinationName: store.destinationName,
                    maximumPlaceCount: store.maximumPlaceCount,
                    bottomSafeAreaInset: bottomSafeAreaInset,
                    memberTapped: { member in
                        store.send(.memberProfileTapped(member))
                    },
                    searchButtonTapped: {
                        store.send(.searchButtonTapped)
                    }
                )
                .frame(height: currentSheetHeight, alignment: .top)
                .clipped()
                .ignoresSafeArea(edges: .bottom)
                .gesture(sheetDragGesture)
            }

        }
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: BottomSafeAreaInsetPreferenceKey.self,
                    value: geometry.safeAreaInsets.bottom
                )
            }
        }
        .onPreferenceChange(BottomSafeAreaInsetPreferenceKey.self) {
            bottomSafeAreaInset = max($0, activeWindowBottomSafeAreaInset())
        }
        .animation(.easeOut(duration: 0.22), value: store.isBottomSheetExpanded)
        .animation(.easeOut(duration: 0.22), value: store.isShowingConfirmedPlaces)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task {
            bottomSafeAreaInset = max(
                bottomSafeAreaInset,
                activeWindowBottomSafeAreaInset()
            )
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { store.isSearchPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.searchDismissed)
                    }
                }
            )
        ) {
            PlaceSearchView(
                store: store.scope(
                    state: \.placeSearch,
                    action: \.placeSearch
                )
            )
        }
        .allowsHitTesting(
            store.completionAlert == nil
                && store.pendingDeletionPlaceID == nil
                && store.placeSyncErrorMessage == nil
                && store.destinationValidationMessage == nil
        )
        .overlay {
            if store.pendingDeletionPlaceID != nil {
                DDAlertOverlay(
                    title: "장소를 삭제할까요?",
                    message: "삭제한 장소는 목록에서 사라져요.",
                    cancelTitle: "아니요",
                    confirmTitle: "네",
                    confirmColor: DDColor.alertDestructive,
                    onCancel: {
                        store.send(.deleteConfirmationCancelTapped)
                    },
                    onConfirm: {
                        store.send(.deleteConfirmationConfirmTapped)
                    }
                )
            } else if let alert = store.completionAlert {
                DDAlertOverlay(
                    title: alert.title,
                    message: store.completionAlertMessage,
                    confirmTitle: "확인",
                    onConfirm: {
                        store.send(.completionAlertConfirmButtonTapped)
                    }
                )
            } else if let message = store.placeSyncErrorMessage {
                DDAlertOverlay(
                    title: "장소를 서버에 저장하지 못했어요",
                    message: message,
                    confirmTitle: "확인",
                    onConfirm: { store.send(.placeSyncErrorDismissed) }
                )
            } else if let message = store.destinationValidationMessage {
                if store.canOverrideDestinationValidation {
                    DDAlertOverlay(
                        title: "여행지와 다른 장소예요",
                        message: message,
                        cancelTitle: "취소",
                        confirmTitle: "그래도 추가",
                        onCancel: {
                            store.send(.destinationValidationCancelButtonTapped)
                        },
                        onConfirm: {
                            store.send(.destinationValidationConfirmButtonTapped)
                        }
                    )
                } else {
                    DDAlertOverlay(
                        title: "장소를 확인할 수 없어요",
                        message: message,
                        confirmTitle: "확인",
                        onConfirm: {
                            store.send(.destinationValidationConfirmButtonTapped)
                        }
                    )
                }
            }
        }
    }

    private var navigationBar: some View {
        placeSelectionNavigationBar
    }

    private var placeSelectionNavigationBar: some View {
        DDNavigationHeader(
            accessibilityLabel: "친구 초대 화면으로 돌아가기",
            alignment: .top,
            height: 62,
            onBack: { store.send(.backButtonTapped) }
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.navigationTitle)
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)

                if store.hasSelectionEnded {
                    Text("모두 장소 선택을 마쳤어요")
                        .ddTypography(.captionEmphasis12)
                        .foregroundStyle(DDColor.textSecondary)
                } else {
                    HStack(spacing: DDSpacing.small) {
                        Image(systemName: "timer")
                            .font(.system(size: 15, weight: .regular))
                            .frame(width: 17, height: 19)

                        Text(store.timerText)
                            .ddTypography(.captionEmphasis12)
                    }
                    .foregroundStyle(DDColor.textSecondary)
                    .frame(height: 19, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42, alignment: .leading)
            .clipped()

            PlaceCountProgressView(
                count: store.selectedPlaceCount,
                maximumCount: store.maximumPlaceCount
            )
        }
        .padding(.trailing, DDSpacing.small)
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        Group {
            if store.selectedPlace != nil {
                HStack(spacing: DDSpacing.small) {
                    Button {
                        store.send(.searchFieldTapped)
                    } label: {
                        HStack(spacing: 0) {
                            Text(store.searchText)
                                .ddTypography(.body16)
                                .foregroundStyle(DDColor.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.send(.searchFieldClearButtonTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(DDColor.textPrimary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("검색 초기화")
                }
                .padding(.horizontal, DDSpacing.xLarge)
                .frame(height: 41)
                .background(DDColor.surfaceElevated)
                .clipShape(.capsule)
                .overlay {
                    Capsule().stroke(DDColor.borderDefault, lineWidth: 1)
                }
            } else {
                Button {
                    store.send(.searchFieldTapped)
                } label: {
                    HStack(spacing: DDSpacing.small) {
                        Image(systemName: "magnifyingglass")

                        Text("꼭 가고 싶은 장소 \(store.maximumPlaceCount)개를 추가하세요.")
                            .ddTypography(.body16)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(DDColor.textSecondary)
                    .padding(.horizontal, DDSpacing.large)
                    .frame(height: 41)
                    .background(DDColor.surfaceElevated)
                    .clipShape(.capsule)
                    .overlay {
                        Capsule().stroke(DDColor.borderSubtle, lineWidth: 1)
                    }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("장소 검색")
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, DDSpacing.medium)
    }

    private var currentSheetHeight: CGFloat {
        let expandedHeight = 288 + bottomSafeAreaInset
        let collapsedHeight = 76 + bottomSafeAreaInset
        let restingHeight = store.isBottomSheetExpanded ? expandedHeight : collapsedHeight
        return min(
            expandedHeight,
            max(collapsedHeight, restingHeight - sheetDragTranslation)
        )
    }

    private var currentMemberSheetHeight: CGFloat {
        let expandedHeight = 379 + bottomSafeAreaInset
        let collapsedHeight = 76 + bottomSafeAreaInset
        let restingHeight = store.isBottomSheetExpanded ? expandedHeight : collapsedHeight
        return min(
            expandedHeight,
            max(collapsedHeight, restingHeight - sheetDragTranslation)
        )
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($sheetDragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                store.send(.bottomSheetDragEnded(value.predictedEndTranslation.height))
            }
    }
}

private struct BottomSafeAreaInsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PlaceCountProgressView: View {
    let count: Int
    let maximumCount: Int

    private var progress: Double {
        guard maximumCount > 0 else { return 0 }
        return min(1, Double(count) / Double(maximumCount))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DDColor.surfaceControl, lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    DDColor.actionPrimary,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(count)/\(maximumCount)")
                .font(.custom("Pretendard-SemiBold", size: 11))
                .foregroundStyle(DDColor.textPrimary)
        }
        .frame(width: 36, height: 36)
        .frame(width: 44, height: 44)
        .animation(.easeOut(duration: 0.2), value: count)
    }
}

#Preview("장소 없음") {
    PlaceSelectionView(store: placeSelectionPreviewStore(state: PlaceSelectionFeature.State()))
}

#Preview("장소 확정·취소") {
    var state = PlaceSelectionFeature.State(
        memberPlaces: PlaceSelectionFeature.State.mockMemberPlaces
    )
    state.isMemberPlacesSheetPresented = true
    state.hasRestoredSavedPlacesPresentation = true
    return PlaceSelectionView(store: placeSelectionPreviewStore(state: state))
}

#Preview("확정 완료 · 드래그 숨김") {
    var state = PlaceSelectionFeature.State(
        memberPlaces: PlaceSelectionFeature.State.mockMemberPlaces
    )
    state.participants[0].isConfirmed = true
    state.isMemberPlacesSheetPresented = true
    state.hasRestoredSavedPlacesPresentation = true
    return PlaceSelectionView(store: placeSelectionPreviewStore(state: state))
}

private func placeSelectionPreviewStore(
    state: PlaceSelectionFeature.State
) -> StoreOf<PlaceSelectionFeature> {
    var client = PlaceClient.testValue
    // Keep local preview edits without accessing a real trip or Google Places.
    client.fetchMemberPlaces = { _ in throw CancellationError() }
    return withDependencies {
        $0.placeClient = client
    } operation: {
        Store(initialState: state) { PlaceSelectionFeature() }
    }
}
