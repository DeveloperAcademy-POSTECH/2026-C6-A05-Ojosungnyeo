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

        var destinationName = "도쿄"
        var countryName = "일본"
        var cityCount = 1
        var travelerCount = 1
        var tripStartDate: Date?
        var tripEndDate: Date?
        var draftStartDate: Date?
        var draftEndDate: Date?
        var isDatePickerPresented = false
        var addFlight = TripSetUpAddFlightFeature.State()
        var isAddFlightPresented = false
        var flightRegistration: TripSetUpAddFlightFeature.FlightRegistration?

        var tripTitle: String { "\(destinationName) 여행" }
        var destinationSummary: String { "\(countryName) · \(cityCount)개 도시" }
        var flightSummary: String { flightRegistration?.outbound.flightNumber ?? "선택 사항" }
        var isSaveEnabled: Bool {
            guard
                let tripStartDate,
                let tripEndDate,
                tripStartDate < tripEndDate
            else { return false }

            return (1...Self.maximumTravelerCount).contains(travelerCount)
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
        case destinationChangeButtonTapped
        case travelScheduleButtonTapped
        case tripDateTapped(Date)
        case tripDatePickerCloseButtonTapped
        case tripDatePickerConfirmButtonTapped
        case travelerDecreaseButtonTapped
        case travelerIncreaseButtonTapped
        case flightInfoButtonTapped
        case addFlightDismissed
        case addFlight(TripSetUpAddFlightFeature.Action)
        case accommodationInfoButtonTapped
        case inviteFriendButtonTapped
        case saveButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
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

                if state.draftEndDate != nil || selectedDate < draftStartDate {
                    state.draftStartDate = selectedDate
                    state.draftEndDate = nil
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
                    let draftEndDate = state.draftEndDate
                else { return .none }

                state.tripStartDate = draftStartDate
                state.tripEndDate = draftEndDate
                state.draftStartDate = nil
                state.draftEndDate = nil
                state.isDatePickerPresented = false
                return .none

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

            case .flightInfoButtonTapped:
                state.addFlight = TripSetUpAddFlightFeature.State(
                    registration: state.flightRegistration
                )
                state.isAddFlightPresented = true
                return .none

            case .addFlightDismissed, .addFlight(.delegate(.dismiss)):
                state.isAddFlightPresented = false
                return .none

            case let .addFlight(.delegate(.completed(registration))):
                state.flightRegistration = registration
                state.isAddFlightPresented = false
                return .none

            case .addFlight:
                return .none

            case .backButtonTapped,
                 .destinationChangeButtonTapped,
                 .accommodationInfoButtonTapped,
                 .inviteFriendButtonTapped:
                return .none
            }
        }

        Scope(state: \.addFlight, action: \.addFlight) {
            TripSetUpAddFlightFeature()
        }
    }
}
