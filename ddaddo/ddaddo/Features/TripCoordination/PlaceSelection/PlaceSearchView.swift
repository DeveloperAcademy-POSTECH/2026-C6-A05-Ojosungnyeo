//
//  PlaceSearchView.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import ComposableArchitecture
import SwiftUI

struct PlaceSearchView: View {
    let store: StoreOf<PlaceSearchFeature>
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 15)
                .padding(.bottom, DDSpacing.xLarge)

            results
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            isSearchFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: DDSpacing.small) {
            Button {
                isSearchFocused = false
                store.send(.closeButtonTapped)
                dismiss()
            } label: {
                PlaceSearchBackIcon()
                    .frame(width: 24, height: 24)
                    .frame(width: 40, height: 41)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("이전 화면으로 돌아가기")

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

            if !store.searchText.isEmpty {
                Button {
                    store.send(.searchTextChanged(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DDColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 41)
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
                ForEach(store.results) { result in
                    Button {
                        store.send(.resultTapped(result))
                    } label: {
                        PlaceSearchResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
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
                ProgressView()
                    .tint(DDColor.actionPrimary)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct PlaceSearchBackIcon: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 16, y: 4))
            path.addLine(to: CGPoint(x: 8, y: 12))
            path.addLine(to: CGPoint(x: 16, y: 20))
        }
        .stroke(
            DDColor.textPrimary,
            style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
        )
    }
}

#Preview {
    PlaceSearchView(
        store: Store(
            initialState: PlaceSearchFeature.State(
                searchText: "스투시 도쿄점",
                results: [
                    PlaceSearchResult(
                        id: "preview",
                        name: "스투시 도쿄점",
                        address: "2 Chome-1004 Tokyo, Chuo Ward, 福岡市 福岡県 810-0001"
                    )
                ]
            )
        ) {
            PlaceSearchFeature()
        }
    )
}
