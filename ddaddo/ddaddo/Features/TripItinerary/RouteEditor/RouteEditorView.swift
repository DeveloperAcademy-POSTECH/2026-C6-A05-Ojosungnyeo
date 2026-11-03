//
//  RouteEditorView.swift
//  ddaddo
//
//  Created by sun on 11/4/26.
//

import ComposableArchitecture
import SwiftUI

struct RouteEditorView: View {
    let store: StoreOf<RouteEditorFeature>

    var body: some View {
        ZStack {
            if let place = store.selectedPlace {
                placeDetail(place)
            } else {
                RouteEditorSearchView(
                    store: store.scope(state: \.search, action: \.search)
                )
            }

            if store.isDaySelectionPresented {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.send(.daySelectionDismissed)
                    }

                daySelectionSheet
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.isDaySelectionPresented)
        .preferredColorScheme(.dark)
    }

    private func placeDetail(_ place: PlaceDetails) -> some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(
                latitude: place.latitude,
                longitude: place.longitude,
                zoom: 15,
                selectedPlace: place
            )
            .ignoresSafeArea()

            VStack {
                Button {
                    store.send(.detailBackButtonTapped)
                } label: {
                    HStack(spacing: DDSpacing.small) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 14, weight: .medium))

                        Text(place.name)
                            .ddTypography(.body16)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.horizontal, DDSpacing.xLarge)
                    .frame(height: 41)
                    .background(DDColor.surfaceElevated)
                    .clipShape(.capsule)
                    .overlay {
                        Capsule().stroke(DDColor.borderDefault, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 15)

                Spacer()
            }

            SelectedPlaceBottomSheet(
                place: place,
                isLoading: store.isPlaceDetailsLoading,
                canAdd: true,
                isAlreadyAdded: false,
                fallbackImageName: nil,
                closeButtonTapped: {
                    store.send(.detailCloseButtonTapped)
                },
                addButtonTapped: {
                    store.send(.addButtonTapped)
                }
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var daySelectionSheet: some View {
        VStack(spacing: DDSpacing.medium) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)

            HStack {
                Text("며칠째에 추가할까요?")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)

                Spacer()

                Button {
                    store.send(.daySelectionDismissed)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(DDColor.textTertiary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: DDSpacing.small) {
                ForEach(store.availableDays) { day in
                    Button {
                        store.send(.daySelected(day))
                    } label: {
                        Text(day.rawValue)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.textPrimary)
                            .frame(width: 64, height: 40)
                            .background(
                                day == store.availableDays.first
                                    ? DDColor.borderDefault
                                    : Color.clear
                            )
                            .clipShape(.capsule)
                            .overlay {
                                Capsule().stroke(DDColor.borderDefault, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, DDSpacing.medium)
        .frame(maxWidth: .infinity)
        .frame(height: 222)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(topLeadingRadius: 28, topTrailingRadius: 28))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct RouteEditorSearchView: View {
    let store: StoreOf<PlaceSearchFeature>
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 15)
                .padding(.bottom, DDSpacing.xLarge)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.results) { result in
                        Button {
                            store.send(.resultTapped(result))
                        } label: {
                            PlaceSearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }

                    if let message = store.errorMessage {
                        Text(message)
                            .ddTypography(.label14)
                            .foregroundStyle(DDColor.statusCritical)
                            .multilineTextAlignment(.center)
                            .padding(DDSpacing.xLarge)
                    }

                    if !store.results.isEmpty {
                        Text("Powered by Google")
                            .ddTypography(.caption12)
                            .foregroundStyle(DDColor.textTertiary)
                            .padding(.vertical, DDSpacing.large)
                    }
                }
            }
            .overlay {
                if store.isLoading {
                    ProgressView().tint(DDColor.actionPrimary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .onAppear { isSearchFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: DDSpacing.small) {
            Button {
                isSearchFocused = false
                store.send(.closeButtonTapped)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            TextField(
                "장소를 검색하세요",
                text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchTextChanged($0)) }
                )
            )
            .ddTypography(.body16)
            .foregroundStyle(DDColor.textPrimary)
            .focused($isSearchFocused)
            .submitLabel(.search)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .frame(height: 41)
        .background(DDColor.surfaceElevated)
        .clipShape(.capsule)
        .overlay {
            Capsule().stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }
}
