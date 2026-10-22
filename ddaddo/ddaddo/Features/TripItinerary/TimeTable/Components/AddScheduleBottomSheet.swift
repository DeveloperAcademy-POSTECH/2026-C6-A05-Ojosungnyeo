//
//  AddScheduleBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/23/26.
//

import ComposableArchitecture
import SwiftUI

struct AddScheduleBottomSheet: View {
    let store: StoreOf<TimeTableFeature>
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("일정 추가")
                .ddTypography(.heading18)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.top, DDSpacing.small)

            searchBar
                .padding(.top, DDSpacing.small)

            Text("도쿄 추천 여행지를 보여드려요")
                .ddTypography(.body16)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.top, DDSpacing.small)

            results
                .padding(.top, DDSpacing.xSmall)
        }
        .padding(.horizontal, 15)
        .background(DDColor.surfaceDefault)
        .preferredColorScheme(.dark)
    }

    private var searchBar: some View {
        HStack(spacing: DDSpacing.small) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DDColor.textPrimary)

            TextField(
                "여기서 검색",
                text: Binding(
                    get: { store.placeSearchText },
                    set: { store.send(.placeSearchTextChanged($0)) }
                )
            )
            .ddTypography(.body16)
            .foregroundStyle(DDColor.textPrimary)
            .focused($isSearchFocused)
            .submitLabel(.search)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !store.placeSearchText.isEmpty {
                Button {
                    store.send(.placeSearchTextChanged(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DDColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 44)
        .background(DDColor.surfaceElevated)
        .clipShape(.capsule)
        .overlay {
            Capsule()
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.placeSearchResults) { result in
                    Button {
                        store.send(.placeSearchResultTapped(result))
                    } label: {
                        resultRow(result)
                    }
                    .buttonStyle(.plain)
                }

                if let message = store.placeSearchErrorMessage {
                    Text(message)
                        .ddTypography(.label14)
                        .foregroundStyle(DDColor.statusCritical)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(DDSpacing.large)
                }

                if !store.placeSearchResults.isEmpty {
                    Text("Powered by Google")
                        .ddTypography(.caption12)
                        .foregroundStyle(DDColor.textTertiary)
                        .padding(.vertical, DDSpacing.large)
                }
            }
        }
        .overlay {
            if store.isPlaceSearchLoading {
                ProgressView()
                    .tint(DDColor.actionPrimary)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func resultRow(_ result: PlaceSearchResult) -> some View {
        HStack(spacing: DDSpacing.large) {
            ZStack {
                Circle()
                    .fill(DDColor.surfaceControl)

                Image(systemName: "clock")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(DDColor.textSecondary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 0) {
                Text(result.name)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                Text(result.address)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(2)

                Divider()
                    .overlay(DDColor.borderSubtle)
                    .padding(.top, DDSpacing.small)
            }
        }
        .frame(minHeight: 77)
        .contentShape(.rect)
    }
}

#Preview {
    AddScheduleBottomSheet(
        store: Store(initialState: TimeTableFeature.State()) {
            TimeTableFeature()
        }
    )
}
