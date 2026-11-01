//
//  PlaceSelectionView.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture
import SwiftUI

struct PlaceSelectionView: View {
    let store: StoreOf<PlaceSelectionFeature>
    @GestureState private var sheetDragTranslation: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(
                selectedPlace: store.selectedPlace,
                showsSelectedPlaceMarker: false,
                pinnedPlaces: store.displayedPlaces,
                onPinnedPlaceTapped: { place in
                    store.send(.pinnedPlaceTapped(place))
                }
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar
                if !store.hasSelectionEnded {
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

            if let selectedPlace = store.selectedPlace {
                SelectedPlaceBottomSheet(
                    place: selectedPlace,
                    isLoading: store.isPlaceDetailsLoading,
                    canAdd: store.canAddSelectedPlace,
                    isAlreadyAdded: store.isSelectedPlaceAlreadyAdded,
                    fallbackImageName: store.selectedPinnedPlace?.thumbnailName
                ) {
                    store.send(.addSelectedPlaceButtonTapped)
                }
                .ignoresSafeArea(edges: .bottom)
            } else if store.isMemberPlacesSheetPresented {
                MemberPlacesBottomSheet(
                    isExpanded: store.isBottomSheetExpanded,
                    selectedMember: store.selectedMember,
                    participants: store.participants,
                    places: store.displayedPlaces,
                    canDeletePlaces: store.isViewingCurrentUser,
                    canConfirm: store.canConfirmPlaceSelection,
                    bottomContentInset: store.hasSelectionEnded ? 124 : DDSpacing.xLarge
                ) { member in
                    store.send(.memberProfileTapped(member))
                } placeTapped: { place in
                    store.send(.pinnedPlaceTapped(place))
                } deletePlace: { place in
                    store.send(.deletePinnedPlaceButtonTapped(place.id))
                } confirmButtonTapped: {
                    store.send(.confirmButtonTapped)
                }
                .frame(height: currentMemberSheetHeight, alignment: .top)
                .clipped()
                .ignoresSafeArea(edges: .bottom)
                .simultaneousGesture(sheetDragGesture)
            } else {
                PlaceSelectionBottomSheet(
                    isExpanded: store.isBottomSheetExpanded,
                    selectedMember: store.selectedMember,
                    participants: store.participants,
                    destinationName: store.destinationName,
                    maximumPlaceCount: store.maximumPlaceCount,
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

            if store.hasSelectionEnded {
                completionCTA
            }
        }
        .animation(.easeOut(duration: 0.22), value: store.isBottomSheetExpanded)
        .animation(.easeOut(duration: 0.22), value: store.hasSelectionEnded)
        .preferredColorScheme(.dark)
        .task {
            await store.send(.onAppear).finish()
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
    }

    private var navigationBar: some View {
        HStack(spacing: DDSpacing.large) {
            Button {
                store.send(.backButtonTapped)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DDColor.iconDefault)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

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
                            .font(.system(size: 13, weight: .semibold))

                        Text(store.timerText)
                            .ddTypography(.captionEmphasis12)
                    }
                    .foregroundStyle(DDColor.textPrimary)
                }
            }

            Spacer(minLength: 0)

            PlaceCountProgressView(
                count: store.selectedPlaceCount,
                maximumCount: store.maximumPlaceCount
            )
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 62)
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
                        store.send(.clearSelectedPlaceButtonTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(DDColor.iconDefault)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DDSpacing.xLarge)
                .frame(height: 41)
                .background(DDColor.surfaceElevated)
                .clipShape(.capsule)
                .overlay {
                    Capsule().stroke(DDColor.borderDefault, lineWidth: 1)
                }
            } else {
                DDSearchField(
                    placeholder: "꼭 가고 싶은 장소 \(store.maximumPlaceCount)개를 추가하세요.",
                    text: Binding(
                        get: { store.searchText },
                        set: { store.send(.searchTextChanged($0)) }
                    )
                )
                .simultaneousGesture(
                    TapGesture().onEnded {
                        store.send(.searchFieldTapped)
                    }
                )
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, DDSpacing.medium)
    }

    private var currentSheetHeight: CGFloat {
        let restingHeight: CGFloat = store.isBottomSheetExpanded ? 322 : 110
        return min(322, max(110, restingHeight - sheetDragTranslation))
    }

    private var currentMemberSheetHeight: CGFloat {
        let restingHeight: CGFloat = store.isBottomSheetExpanded ? 413 : 110
        return min(413, max(110, restingHeight - sheetDragTranslation))
    }

    private var completionCTA: some View {
        DDCTAButton(title: "이동 기준 정하기") {
            store.send(.moveCriteriaButtonTapped)
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.bottom, 20)
        .background(DDColor.surfaceDefault)
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
                .ddTypography(.captionEmphasis12)
                .foregroundStyle(DDColor.textPrimary)
        }
        .frame(width: 44, height: 44)
        .animation(.easeOut(duration: 0.2), value: count)
    }
}

#Preview {
    PlaceSelectionView(
        store: Store(initialState: PlaceSelectionFeature.State()) {
            PlaceSelectionFeature()
        }
    )
}
