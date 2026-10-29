//
//  TripSetUpFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct TripSetUpFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        static let maximumTravelerCount = 4

        var selectedCities: [TripSearchFeature.City] = []
        var travelerCount = 1
        var tripStartDate: Date?
        var tripEndDate: Date?
        var transportationSelection: TripSetUpTransportationFeature.Selection?
        var transportationSheet = TripSetUpTransportationFeature.State()
        var isTransportationSheetPresented = false

        var tripTitle: String {
            guard let firstCity = selectedCities.first else { return "" }
            guard selectedCities.count > 1 else { return "\(firstCity.name) 여행" }
            return "\(firstCity.name) 외 \(selectedCities.count - 1)개 도시 여행"
        }

        var destinationSummary: String {
            guard !selectedCities.isEmpty else { return "" }
            var countries: [String] = []
            for city in selectedCities where !countries.contains(city.country) {
                countries.append(city.country)
            }
            return "\(countries.joined(separator: ", ")) · \(selectedCities.count)개 도시"
        }
        var transportationSummary: String? {
            guard let transportationSelection else { return nil }
            return "\(transportationSelection.transportation.title) · \(transportationSelection.duration.title)"
        }
        var isSaveEnabled: Bool {
            guard
                let tripStartDate,
                let tripEndDate,
                tripStartDate < tripEndDate
            else { return false }

            return (1...Self.maximumTravelerCount).contains(travelerCount)
                && transportationSelection != nil
        }

        var tripDateSummary: String? {
            guard let tripStartDate, let tripEndDate else { return nil }

            let calendar = Calendar.autoupdatingCurrent
            let start = calendar.dateComponents([.year, .month, .day], from: tripStartDate)
            let end = calendar.dateComponents([.year, .month, .day], from: tripEndDate)

            guard
                let startYear = start.year,
                let startMonth = start.month,
                let startDay = start.day,
                let endYear = end.year,
                let endMonth = end.month,
                let endDay = end.day
            else { return nil }

            if startYear == endYear, startMonth == endMonth {
                return "\(startMonth)월 \(startDay)일 ~ \(endDay)일"
            }

            if startYear == endYear {
                return "\(startMonth)월 \(startDay)일 ~ \(endMonth)월 \(endDay)일"
            }

            return "\(startYear)년 \(startMonth)월 \(startDay)일 ~ \(endYear)년 \(endMonth)월 \(endDay)일"
        }
    }

    @CasePathable
    enum Action: Equatable {
        case backButtonTapped
        case travelerDecreaseButtonTapped
        case travelerIncreaseButtonTapped
        case transportationCardTapped
        case transportationSheetDismissed
        case transportationSheet(TripSetUpTransportationFeature.Action)
        case saveButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
<<<<<<< HEAD
            case .travelScheduleButtonTapped:
                state.draftStartDate = state.tripStartDate
                state.draftEndDate = state.tripEndDate
                state.isDatePickerPresented = true
                return .none

            case let .tripDateTapped(date):
                let calendar = Calendar.autoupdatingCurrent
                let selectedDate = calendar.startOfDay(for: date)
                let today = calendar.startOfDay(for: Date())
                guard selectedDate >= today else { return .none }

                guard let draftStartDate = state.draftStartDate else {
                    state.draftStartDate = selectedDate
                    state.draftEndDate = nil
                    return .none
                }

                if state.draftEndDate != nil {
                    state.draftStartDate = selectedDate
                    state.draftEndDate = nil
                } else if selectedDate < draftStartDate {
                    state.draftStartDate = selectedDate
                    state.draftEndDate = draftStartDate
                } else if selectedDate > draftStartDate {
                    state.draftEndDate = selectedDate
                }
                return .none

            case .tripDatePickerCloseButtonTapped:
                state.draftStartDate = nil
                state.draftEndDate = nil
                state.isDatePickerPresented = false
                return .none

            case .tripDatePickerConfirmButtonTapped:
                guard
                    let draftStartDate = state.draftStartDate,
                    let draftEndDate = state.draftEndDate,
                    draftStartDate < draftEndDate
                else { return .none }

                state.tripStartDate = draftStartDate
                state.tripEndDate = draftEndDate
                state.draftStartDate = nil
                state.draftEndDate = nil
                state.isDatePickerPresented = false
                return .none

=======
>>>>>>> develop
            case .saveButtonTapped:
                guard state.isSaveEnabled else { return .none }
                return .none

            case .travelerDecreaseButtonTapped:
                guard state.travelerCount > 1 else { return .none }
                state.travelerCount -= 1
                return .none

            case .travelerIncreaseButtonTapped:
                guard state.travelerCount < State.maximumTravelerCount else { return .none }
                state.travelerCount += 1
                return .none

            case .transportationCardTapped:
                state.transportationSheet = TripSetUpTransportationFeature.State(
                    selection: state.transportationSelection
                )
                state.isTransportationSheetPresented = true
                return .none

            case .transportationSheetDismissed,
                 .transportationSheet(.delegate(.dismiss)):
                state.isTransportationSheetPresented = false
                return .none

            case let .transportationSheet(.delegate(.completed(selection))):
                state.transportationSelection = selection
                state.isTransportationSheetPresented = false
                return .none

            case .transportationSheet:
                return .none

            case .backButtonTapped:
                return .none
            }
        }

        Scope(state: \.transportationSheet, action: \.transportationSheet) {
            TripSetUpTransportationFeature()
        }
    }
}
