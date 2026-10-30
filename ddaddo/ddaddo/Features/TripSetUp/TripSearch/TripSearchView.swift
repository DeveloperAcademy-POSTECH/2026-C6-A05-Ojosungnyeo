//
//  TripSearchView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct TripSearchView: View {
    let store: StoreOf<TripSearchFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, DDSpacing.large)

                searchField
                    .padding(.horizontal, DDSpacing.large)
                    .padding(.top, DDSpacing.large)

                regionFilters
                    .padding(.top, DDSpacing.large)

                cityList
                    .padding(.top, DDSpacing.xLarge)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                selectionArea
            }
            .background(DDColor.surfaceDefault.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .navigationDestination(
                isPresented: Binding(
                    get: { store.isTripSetUpPresented },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.tripSetUpDismissed)
                        }
                    }
                )
            ) {
                TripSetUpView(
                    store: store.scope(
                        state: \.tripSetUp,
                        action: \.tripSetUp
                    )
                )
            }
        }
        .task { store.send(.onAppear) }
    }

    private var header: some View {
        HStack(spacing: DDSpacing.small) {
            Button {
                store.send(.backButtonTapped)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 24, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로 가기")

            Text("여행지 검색")
                .ddTypography(.title24)
                .foregroundStyle(DDColor.textPrimary)

            Spacer()
        }
        .frame(height: 52)
    }

    private var searchField: some View {
        DDSearchField(
            placeholder: "도시/지역 이름 (예: 도쿄)",
            text: Binding(
                get: { store.searchText },
                set: { store.send(.searchTextChanged($0)) }
            )
        )
        .overlay {
            Capsule()
                .stroke(DDColor.borderDefault.opacity(0.8), lineWidth: 1)
        }
    }

    private var regionFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TripSearchFeature.Region.allCases, id: \.self) { region in
                    Button {
                        store.send(.regionFilterSelected(region))
                    } label: {
                        Text(region.rawValue)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(store.selectedRegion == region ? DDColor.textOnPrimary : DDColor.textPrimary)
                            .padding(.horizontal, region == .americasAndOceania ? DDSpacing.xLarge : 18)
                            .frame(height: 36)
                            .background(store.selectedRegion == region ? DDColor.actionPrimary : DDColor.actionSecondary)
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DDSpacing.large)
        }
    }

    private var cityList: some View {
        Group {
            if store.isLoading {
                ProgressView()
                    .tint(DDColor.actionPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = store.errorMessage {
                VStack(spacing: DDSpacing.small) {
                    Text("여행지를 불러오지 못했어요.")
                        .ddTypography(.bodyEmphasis16)
                        .foregroundStyle(DDColor.textPrimary)
                    Text(errorMessage)
                        .ddTypography(.label14)
                        .foregroundStyle(DDColor.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("다시 시도") { store.send(.onAppear) }
                        .foregroundStyle(DDColor.actionPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, DDSpacing.large)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DDSpacing.medium) {
                        ForEach(groupedCities) { group in
                            Text(group.country)
                                .ddTypography(.caption12)
                                .foregroundStyle(DDColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(group.cities) { city in
                                Button {
                                    store.send(.cityTapped(city.id))
                                } label: {
                                    cityRow(city)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(store.selectedCityIDs.contains(city.id) ? .isSelected : [])
                            }
                        }
                    }
                    .padding(.horizontal, DDSpacing.large)
                    .padding(.bottom, DDSpacing.large)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private var selectionArea: some View {
        VStack(alignment: .leading, spacing: DDSpacing.medium) {
            Text("선택한 여행지 \(store.selectedCities.count)")
                .ddTypography(.captionEmphasis12)
                .foregroundStyle(DDColor.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DDSpacing.small) {
                    ForEach(store.selectedCities) { city in
                        selectedCityChip(city)
                    }
                }
            }
            .frame(height: 32)

            DDCTAButton(
                title: "\(store.selectedCities.count)개 도시로 여행 만들기",
                isEnabled: !store.selectedCities.isEmpty,
                action: { store.send(.nextButtonTapped) }
            )
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, 5)
        .padding(.bottom, 11)
        .background(DDColor.surfaceDefault)
    }

    private func selectedCityChip(_ city: TripSearchFeature.City) -> some View {
        HStack(spacing: DDSpacing.small) {
            Text(city.name)
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.textPrimary)

            Button {
                store.send(.selectedCityRemoveButtonTapped(city.id))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(city.name) 선택 해제")
        }
        .padding(.horizontal, DDSpacing.medium)
        .frame(height: 32)
        .background(DDColor.surfaceElevated)
        .clipShape(.capsule)
    }

    private func cityRow(_ city: TripSearchFeature.City) -> some View {
        let isSelected = store.selectedCityIDs.contains(city.id)

        return HStack(spacing: 23) {
            Image(city.thumbnailName)
                .resizable()
                .scaledToFill()
                .frame(width: 47, height: 47)
                .clipped()
                .background(.white)
                .clipShape(.rect(cornerRadius: 12))

            Text(city.name)
                .ddTypography(.body16)
                .foregroundStyle(isSelected ? DDColor.textPrimary : DDColor.textTertiary)

            Spacer(minLength: 0)

            ZStack {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DDColor.textOnPrimary)
                }
            }
            .frame(width: 20, height: 20)
            .background(isSelected ? DDColor.actionPrimary : .clear)
            .clipShape(.rect(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? DDColor.textOnPrimary : DDColor.borderDefault.opacity(0.8), lineWidth: 1)
            }
        }
        .frame(height: 60)
        .contentShape(Rectangle())
    }

    private var groupedCities: [TripSearchCountryGroup] {
        var countries: [String] = []
        var citiesByCountry: [String: [TripSearchFeature.City]] = [:]

        for city in store.filteredCities {
            if citiesByCountry[city.country] == nil {
                countries.append(city.country)
            }
            citiesByCountry[city.country, default: []].append(city)
        }

        return countries.map { country in
            TripSearchCountryGroup(
                country: country,
                cities: citiesByCountry[country] ?? []
            )
        }
    }
}

private struct TripSearchCountryGroup: Identifiable {
    let country: String
    let cities: [TripSearchFeature.City]

    var id: String { country }
}

#Preview {
    TripSearchView(
        store: Store(
            initialState: TripSearchFeature.State(
                selectedCityIDs: ["tokyo"]
            )
        ) {
            TripSearchFeature()
        }
    )
}
