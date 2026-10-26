//
//  TripSearchView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct TripSearchView: View {
    let store: StoreOf<TripSearchFeature>

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, DDSpacing.large)

            DDProgressBar(currentStep: 1)
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.xLarge)

            searchField
                .padding(.horizontal, DDSpacing.large)

            regionFilters
                .padding(.top, 14)

            cityList
                .padding(.top, 14)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            selectionArea
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .preferredColorScheme(.dark)
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

            HStack(spacing: DDSpacing.xSmall) {
                Text("여행지를 찾아보게따")
                    .ddTypography(.title24)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
            }
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
    }

    private var regionFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TripSearchFeature.Region.allCases, id: \.self) { region in
                    DDScheduleFilterChip(
                        title: region.rawValue,
                        isSelected: store.selectedRegion == region,
                        action: { store.send(.regionFilterSelected(region)) }
                    )
                }
            }
            .padding(.horizontal, DDSpacing.large)
        }
    }

    private var cityList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(groupedCities) { group in
                    Text(group.country)
                        .ddTypography(.caption12)
                        .foregroundStyle(DDColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(group.cities) { city in
                        Button {
                            store.send(.cityTapped(city.id))
                        } label: {
                            DDDestinationRow(
                                title: city.name,
                                isSelected: store.selectedCityIDs.contains(city.id)
                            ) {
                                if let thumbnail = UIImage(named: city.thumbnailName) {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 20))
                                        .foregroundStyle(DDColor.textSecondary)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.bottom, DDSpacing.large)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var selectionArea: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        .padding(.top, DDSpacing.medium)
        .padding(.bottom, DDSpacing.medium)
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
        .clipShape(.rect(cornerRadius: DDRadius.medium))
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
