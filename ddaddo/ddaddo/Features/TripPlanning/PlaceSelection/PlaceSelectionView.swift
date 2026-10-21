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
                pinnedPlaces: store.displayedPlaces
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar
                searchField
                Spacer()
            }

            if store.isBottomSheetExpanded
                && store.selectedPlace == nil
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
                    isLoading: store.isPlaceDetailsLoading
                )
                .ignoresSafeArea(edges: .bottom)
            } else if !store.displayedPlaces.isEmpty {
                MemberPlacesBottomSheet(
                    isExpanded: store.isBottomSheetExpanded,
                    selectedMember: store.selectedMember,
                    places: store.displayedPlaces
                ) { member in
                    store.send(.memberProfileTapped(member))
                }
                .frame(height: currentMemberSheetHeight, alignment: .top)
                .clipped()
                .ignoresSafeArea(edges: .bottom)
                .gesture(sheetDragGesture)
            } else {
                PlaceSelectionBottomSheet(
                    isExpanded: store.isBottomSheetExpanded
                ) {
                    store.send(.searchButtonTapped)
                }
                .frame(height: currentSheetHeight, alignment: .top)
                .clipped()
                .ignoresSafeArea(edges: .bottom)
                .gesture(sheetDragGesture)
            }
        }
        .animation(.easeOut(duration: 0.22), value: store.isBottomSheetExpanded)
        .preferredColorScheme(.dark)
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
                Text("3박 4일 도쿄여행")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)

                HStack(spacing: DDSpacing.small) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))

                    Text("06:34:05")
                        .ddTypography(.captionEmphasis12)
                }
                .foregroundStyle(DDColor.textPrimary)
            }

            Spacer(minLength: 0)

            Text(store.selectedPlace == nil ? "2/3" : "1/3")
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.horizontal, DDSpacing.small)
                .frame(height: 32)
                .background(DDColor.surfaceDefault)
                .clipShape(.capsule)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 62)
    }

    private var searchField: some View {
        Group {
            if store.selectedPlace != nil {
                HStack(spacing: DDSpacing.small) {
                    Text(store.searchText)
                        .ddTypography(.body16)
                        .foregroundStyle(DDColor.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

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
                    placeholder: store.displayedPlaces.isEmpty
                        ? "꼭 가고 싶은 장소 8개를 추가하세요"
                        : "꼭 가고 싶은 장소 3개를 추가하세요.",
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
        .padding(.top, DDSpacing.zero)
    }

    private var currentSheetHeight: CGFloat {
        let restingHeight: CGFloat = store.isBottomSheetExpanded ? 322 : 156
        return min(322, max(156, restingHeight - sheetDragTranslation))
    }

    private var currentMemberSheetHeight: CGFloat {
        let restingHeight: CGFloat = store.isBottomSheetExpanded ? 535 : 156
        return min(535, max(156, restingHeight - sheetDragTranslation))
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

#Preview {
    PlaceSelectionView(
        store: Store(initialState: PlaceSelectionFeature.State()) {
            PlaceSelectionFeature()
        }
    )
}
