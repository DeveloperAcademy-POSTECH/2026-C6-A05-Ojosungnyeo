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
            }

            if store.isDaySelectionPresented {
                daySelectionSheet
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(
            .easeOut(duration: 0.2),
            value: store.isDaySelectionPresented
        )
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
                .padding(.horizontal, DDSpacing.large)

                Spacer()
            }

            SelectedPlaceBottomSheet(
                place: place,
                isLoading: store.isPlaceDetailsLoading,
                canAdd: !store.isPlaceDetailsLoading,
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
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, DDSpacing.medium)
                .padding(.bottom, DDSpacing.medium)

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
            .padding(.horizontal, DDSpacing.large)

            ScrollView(.horizontal) {
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
                                    day == store.selectedDay
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
                }
                .padding(.horizontal, DDSpacing.large)
            }
            .scrollIndicators(.hidden)
            .padding(.top, DDSpacing.small)

            Text("누구랑 여행할까요?")
                .ddTypography(.heading18)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.horizontal, DDSpacing.large)
                .padding(.top, DDSpacing.large)

            HStack(spacing: DDSpacing.small) {
                Button {
                    store.send(.aloneButtonTapped)
                } label: {
                    Text("혼자")
                        .ddTypography(.labelEmphasis14)
                        .foregroundStyle(DDColor.textPrimary)
                        .frame(width: 64, height: 40)
                        .background(Color.clear)
                        .clipShape(.capsule)
                        .overlay {
                            Capsule().stroke(DDColor.borderDefault, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(store.selectedDay == nil)

                Button {
                    store.send(.withFriendsButtonTapped)
                } label: {
                    Text("친구랑")
                        .ddTypography(.labelEmphasis14)
                        .foregroundStyle(DDColor.textPrimary)
                        .frame(width: 72, height: 40)
                        .background(
                            store.isFriendSelectionPresented
                                ? DDColor.borderDefault
                                : Color.clear
                        )
                        .clipShape(.capsule)
                        .overlay {
                            Capsule().stroke(DDColor.borderDefault, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(store.selectedDay == nil || store.availableFriends.isEmpty)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, DDSpacing.medium)

            if store.isFriendSelectionPresented {
                HStack {
                    Text("함께 갈 친구를 골라주세요")
                        .ddTypography(.labelEmphasis14)
                        .foregroundStyle(DDColor.textPrimary)

                    Spacer(minLength: 0)

                    Text("1명 선택")
                        .ddTypography(.label14)
                        .foregroundStyle(DDColor.textSecondary)
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.top, DDSpacing.large)

                ScrollView(.horizontal) {
                    HStack(spacing: DDSpacing.medium) {
                        ForEach(store.availableFriends) { member in
                            friendButton(member)
                        }
                    }
                    .padding(.horizontal, DDSpacing.large)
                }
                .scrollIndicators(.hidden)
                .padding(.top, DDSpacing.small)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 562)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(topLeadingRadius: 28, topTrailingRadius: 28))
        .ddBottomSheetBorder(cornerRadius: 28)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ddFillBottomSheetToScreenEdge(color: DDColor.surfaceElevated)
        .ignoresSafeArea(edges: .bottom)
    }

    private func friendButton(_ member: TripMember) -> some View {
        let isSelected = store.selectedFriends.contains(member)

        return Button {
            store.send(.friendTapped(member))
        } label: {
            VStack(spacing: DDSpacing.small) {
                ZStack(alignment: .topTrailing) {
                    DDMiniHeadAvatar(character: member.avatar, size: 64)
                        .overlay {
                            Circle()
                                .stroke(
                                    isSelected ? DDColor.actionPrimary : Color.clear,
                                    lineWidth: 3
                                )
                        }

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DDColor.textOnPrimary)
                            .frame(width: 20, height: 20)
                            .background(DDColor.actionPrimary, in: Circle())
                    }
                }

                Text(member.accessibilityName)
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(
                        isSelected ? DDColor.textPrimary : DDColor.textSecondary
                    )
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(member.accessibilityName) 선택")
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }
}

private struct RouteEditorSearchView: View {
    let store: StoreOf<PlaceSearchFeature>
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, DDSpacing.large)
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
