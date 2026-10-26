//
//  TripSetUpAddAccommodationView.swift
//  ddaddo
//

import ComposableArchitecture
import CoreLocation
import SwiftUI
import UIKit

struct TripSetUpAddAccommodationView: View {
    let store: StoreOf<TripSetUpAddAccommodationFeature>
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        Group {
            switch store.step {
            case .search:
                searchScreen
            case .detail:
                detailScreen
            }
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task(id: store.step) {
            if store.step == .search {
                await Task.yield()
                isSearchFocused = true
            } else {
                isSearchFocused = false
            }
        }
    }

    private var searchScreen: some View {
        VStack(spacing: 0) {
            screenHeader

            DDProgressBar(currentStep: 3)
                .padding(.horizontal, DDSpacing.large)

            DDSearchField(
                placeholder: "숙소 이름이나 주소를 검색하세요",
                text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchTextChanged($0)) }
                ),
                focus: $isSearchFocused
            )
            .submitLabel(.search)
            .onSubmit {
                isSearchFocused = false
                store.send(.searchButtonTapped)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 28)

            if !store.searchResults.isEmpty {
                searchResults
            } else {
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isSearchFocused {
                DDCTAButton(
                    title: "숙소 검색하기",
                    style: store.isSearchEnabled ? .primary : .secondary,
                    isEnabled: store.isSearchEnabled
                ) {
                    isSearchFocused = false
                    store.send(.searchButtonTapped)
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.top, DDSpacing.medium)
                .padding(.bottom, DDSpacing.medium)
                .background(DDColor.surfaceDefault)
            }
        }
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("검색 결과")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.bottom, DDSpacing.medium)

                ForEach(store.searchResults) { accommodation in
                    accommodationRow(accommodation)
                }
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 32)
            .padding(.bottom, DDSpacing.large)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private func accommodationRow(
        _ accommodation: TripSetUpAddAccommodationFeature.Accommodation
    ) -> some View {
        HStack(spacing: DDSpacing.small) {
            Image(accommodation.thumbnailImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(.rect(cornerRadius: DDRadius.small))

            VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
                Text(accommodation.name)
                    .ddTypography(.body16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                Text(accommodation.address)
                    .ddTypography(.body16)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                isSearchFocused = false
                store.send(.accommodationSelected(accommodation.id))
            } label: {
                Text("선택")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 48, height: 29)
                    .background(DDColor.surfaceControl)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DDSpacing.small)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(DDColor.borderSubtle)
                .padding(.leading, 68)
        }
    }

    private var detailScreen: some View {
        VStack(spacing: 0) {
            screenHeader

            DDProgressBar(currentStep: 3)
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, 38)

            if let accommodation = store.selectedAccommodation {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Image(accommodation.heroImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 207)
                            .clipShape(.rect(cornerRadius: DDRadius.medium))
                            .clipped()

                        Text(accommodation.name)
                            .ddTypography(.heading18)
                            .foregroundStyle(DDColor.textPrimary)
                            .padding(.top, DDSpacing.xLarge)

                        Text("숙박 업소")
                            .ddTypography(.caption12)
                            .foregroundStyle(DDColor.textSecondary)
                            .padding(.top, DDSpacing.small)

                        HStack(spacing: 2) {
                            Image(systemName: "mappin")

                            Text(accommodation.address)
                                .underline()
                                .lineLimit(1)

                            Button {
                                UIPasteboard.general.string = accommodation.address
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 16))
                                    .frame(width: 24, height: 24)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("숙소 주소 복사")
                        }
                        .ddTypography(.body16)
                        .foregroundStyle(DDColor.textSecondary)
                        .padding(.top, DDSpacing.xSmall)

                        if let websiteURL = URL(string: accommodation.website) {
                            Link(destination: websiteURL) {
                                Label(accommodation.website, systemImage: "globe")
                                    .ddTypography(.body16)
                                    .foregroundStyle(DDColor.textPrimary)
                                    .underline()
                                    .lineLimit(1)
                            }
                            .padding(.top, DDSpacing.xSmall)
                        }

                        GoogleMapView(
                            latitude: accommodation.latitude,
                            longitude: accommodation.longitude,
                            selectedCoordinate: CLLocationCoordinate2D(
                                latitude: accommodation.latitude,
                                longitude: accommodation.longitude
                            )
                        )
                            .frame(maxWidth: .infinity)
                            .frame(height: 207)
                            .clipShape(.rect(cornerRadius: DDRadius.medium))
                            .clipped()
                            .padding(.top, DDSpacing.xLarge)
                    }
                    .padding(.horizontal, DDSpacing.large)
                    .padding(.bottom, DDSpacing.large)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DDCTAButton(title: "숙소 추가하기") {
                store.send(.addAccommodationButtonTapped)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, DDSpacing.medium)
            .padding(.bottom, DDSpacing.medium)
            .background(DDColor.surfaceDefault)
        }
    }

    private var screenHeader: some View {
        HStack(spacing: DDSpacing.small) {
            Button {
                store.send(.backButtonTapped)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 24, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로 가기")

            HStack(spacing: DDSpacing.xSmall) {
                Text("숙소를 등록하게따")
                    .ddTypography(.title24)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundStyle(DDColor.textPrimary)

            Spacer()
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 52)
    }
}

#Preview("숙소 검색") {
    TripSetUpAddAccommodationView(
        store: Store(initialState: TripSetUpAddAccommodationFeature.State()) {
            TripSetUpAddAccommodationFeature()
        }
    )
}
