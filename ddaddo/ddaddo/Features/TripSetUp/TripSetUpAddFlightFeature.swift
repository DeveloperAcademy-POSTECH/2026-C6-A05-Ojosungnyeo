//
//  TripSetUpAddFlightFeature.swift
//  ddaddo
//

import ComposableArchitecture
import Foundation

struct TripSetUpAddFlightFeature: Reducer {
    struct Flight: Equatable {
        var flightNumber = ""
        var departureDate: Date?
    }

    struct FlightRegistration: Equatable {
        var outbound: Flight
        var returnFlight: Flight?
        var reservationNumber: String
        var voucherFileName: String?
    }

    enum Step: Equatable {
        case flightNumber
        case departureDate
        case confirmation
    }

    enum EditingLeg: Equatable {
        case outbound
        case returnFlight
    }

    enum EntryPurpose: Equatable {
        case adding
        case editingFlightNumber
        case editingDepartureDate
    }

    @ObservableState
    struct State: Equatable {
        var step: Step = .flightNumber
        var editingLeg: EditingLeg = .outbound
        var entryPurpose: EntryPurpose = .adding
        var outbound = Flight()
        var returnFlight: Flight?
        var flightNumberInput = ""
        var draftDepartureDate: Date?
        var reservationNumber = ""
        var voucherFileName: String?
        var isVoucherPickerPresented = false

        init(registration: FlightRegistration? = nil) {
            guard let registration else { return }
            step = .confirmation
            outbound = registration.outbound
            returnFlight = registration.returnFlight
            reservationNumber = registration.reservationNumber
            voucherFileName = registration.voucherFileName
        }

        var isFlightNumberValid: Bool {
            Self.isValidFlightNumber(flightNumberInput)
        }

        private static func isValidFlightNumber(_ flightNumber: String) -> Bool {
            flightNumber.contains { !$0.isWhitespace }
        }

        var isRegistrationEnabled: Bool {
            guard
                Self.isValidFlightNumber(outbound.flightNumber),
                outbound.departureDate != nil
            else { return false }

            guard let returnFlight else { return true }
            return Self.isValidFlightNumber(returnFlight.flightNumber)
                && returnFlight.departureDate != nil
        }

        var registration: FlightRegistration? {
            guard isRegistrationEnabled else { return nil }
            return FlightRegistration(
                outbound: outbound,
                returnFlight: returnFlight,
                reservationNumber: reservationNumber,
                voucherFileName: voucherFileName
            )
        }
    }

    enum Action: Equatable {
        case backButtonTapped
        case flightNumberChanged(String)
        case flightNumberSubmitted
        case departureDateTapped(Date)
        case departureDatePickerCloseButtonTapped
        case departureDatePickerConfirmButtonTapped
        case flightNumberEditButtonTapped(EditingLeg)
        case departureDateEditButtonTapped(EditingLeg)
        case flightNumberRemoveButtonTapped
        case returnFlightAddButtonTapped
        case returnFlightRemoveButtonTapped
        case reservationNumberChanged(String)
        case voucherAreaTapped
        case voucherPickerDismissed
        case voucherFileSelected(String)
        case voucherRemoveButtonTapped
        case addFlightButtonTapped
        case delegate(DelegateAction)
    }

    enum DelegateAction: Equatable {
        case dismiss
        case completed(FlightRegistration)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                if state.step == .flightNumber,
                   (state.editingLeg == .returnFlight || state.entryPurpose == .editingFlightNumber) {
                    if state.returnFlight?.departureDate == nil {
                        state.returnFlight = nil
                    }
                    state.entryPurpose = .adding
                    state.step = .confirmation
                    return .none
                }
                return .send(.delegate(.dismiss))

            case let .flightNumberChanged(value):
                state.flightNumberInput = String(
                    value.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(8)
                )
                return .none

            case .flightNumberSubmitted:
                guard state.isFlightNumberValid else { return .none }
                switch state.editingLeg {
                case .outbound:
                    state.outbound.flightNumber = state.flightNumberInput
                    state.draftDepartureDate = state.outbound.departureDate
                case .returnFlight:
                    var returnFlight = state.returnFlight ?? Flight()
                    returnFlight.flightNumber = state.flightNumberInput
                    state.returnFlight = returnFlight
                }

                if state.entryPurpose == .editingFlightNumber {
                    state.entryPurpose = .adding
                    state.step = .confirmation
                    return .none
                }

                state.draftDepartureDate = state.editingLeg == .outbound
                    ? state.outbound.departureDate
                    : state.returnFlight?.departureDate
                state.step = .departureDate
                return .none

            case let .departureDateTapped(date):
                let calendar = Calendar.autoupdatingCurrent
                let selectedDate = calendar.startOfDay(for: date)
                guard selectedDate >= calendar.startOfDay(for: Date()) else { return .none }
                state.draftDepartureDate = selectedDate
                return .none

            case .departureDatePickerCloseButtonTapped:
                state.draftDepartureDate = nil
                if state.entryPurpose == .editingDepartureDate {
                    state.entryPurpose = .adding
                    state.step = .confirmation
                } else {
                    state.step = .flightNumber
                }
                return .none

            case .departureDatePickerConfirmButtonTapped:
                guard let departureDate = state.draftDepartureDate else { return .none }
                switch state.editingLeg {
                case .outbound:
                    state.outbound.departureDate = departureDate
                case .returnFlight:
                    state.returnFlight?.departureDate = departureDate
                }
                state.draftDepartureDate = nil
                state.entryPurpose = .adding
                state.step = .confirmation
                return .none

            case let .flightNumberEditButtonTapped(leg):
                state.editingLeg = leg
                state.entryPurpose = .editingFlightNumber
                state.flightNumberInput = leg == .outbound
                    ? state.outbound.flightNumber
                    : state.returnFlight?.flightNumber ?? ""
                state.step = .flightNumber
                return .none

            case let .departureDateEditButtonTapped(leg):
                state.editingLeg = leg
                state.entryPurpose = .editingDepartureDate
                state.draftDepartureDate = leg == .outbound
                    ? state.outbound.departureDate
                    : state.returnFlight?.departureDate
                state.step = .departureDate
                return .none

            case .flightNumberRemoveButtonTapped:
                state.outbound = Flight()
                state.editingLeg = .outbound
                state.entryPurpose = .adding
                state.flightNumberInput = ""
                state.step = .flightNumber
                return .none

            case .returnFlightAddButtonTapped:
                state.editingLeg = .returnFlight
                state.entryPurpose = .adding
                state.flightNumberInput = state.returnFlight?.flightNumber ?? ""
                state.step = .flightNumber
                return .none

            case .returnFlightRemoveButtonTapped:
                state.returnFlight = nil
                return .none

            case let .reservationNumberChanged(value):
                state.reservationNumber = value
                return .none

            case .voucherAreaTapped:
                state.isVoucherPickerPresented = true
                return .none

            case .voucherPickerDismissed:
                state.isVoucherPickerPresented = false
                return .none

            case let .voucherFileSelected(fileName):
                state.voucherFileName = fileName
                state.isVoucherPickerPresented = false
                return .none

            case .voucherRemoveButtonTapped:
                state.voucherFileName = nil
                return .none

            case .addFlightButtonTapped:
                guard let registration = state.registration else { return .none }
                return .send(.delegate(.completed(registration)))

            case .delegate:
                return .none
            }
        }
    }
}
