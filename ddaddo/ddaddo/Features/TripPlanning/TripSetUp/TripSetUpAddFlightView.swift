//
//  TripSetUpAddFlightView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct TripSetUpAddFlightView: View {
    let store: StoreOf<TripSetUpAddFlightFeature>
    @FocusState private var isFlightNumberFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            switch store.step {
            case .flightNumber, .departureDate:
                flightNumberEntryScreen
            case .confirmation:
                confirmationScreen
            }

            if store.step == .departureDate {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()

                TripDatePickerView(
                    selectionMode: .single,
                    selectedStartDate: store.draftDepartureDate,
                    selectedEndDate: nil,
                    onDateSelected: { store.send(.departureDateTapped($0)) },
                    onClose: { store.send(.departureDatePickerCloseButtonTapped) },
                    onConfirm: { store.send(.departureDatePickerConfirmButtonTapped) }
                )
                .frame(maxHeight: 710)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.step)
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            isFlightNumberFocused = store.step == .flightNumber
        }
        .onChange(of: store.step) { _, step in
            isFlightNumberFocused = step == .flightNumber
        }
        .fileImporter(
            isPresented: Binding(
                get: { store.isVoucherPickerPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.voucherPickerDismissed)
                    }
                }
            ),
            allowedContentTypes: [.pdf, .image]
        ) { result in
            switch result {
            case let .success(url):
                store.send(.voucherFileSelected(url.lastPathComponent))
            case .failure:
                store.send(.voucherPickerDismissed)
            }
        }
    }

    private var flightNumberEntryScreen: some View {
        VStack(spacing: 0) {
            screenHeader

            DDProgressBar(currentStep: 3)
                .padding(.horizontal, DDSpacing.large)

            VStack(alignment: .leading, spacing: DDSpacing.large) {
                Text(store.editingLeg == .outbound ? "편명을 등록하세요." : "돌아오는 편명을 등록하세요.")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)

                flightNumberField
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 38)

            Spacer()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.step == .flightNumber {
                DDCTAButton(
                    title: "다음",
                    style: store.isFlightNumberValid ? .primary : .secondary,
                    isEnabled: store.isFlightNumberValid
                ) {
                    isFlightNumberFocused = false
                    store.send(.flightNumberSubmitted)
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.top, DDSpacing.medium)
                .padding(.bottom, DDSpacing.medium)
                .background(DDColor.surfaceDefault)
            }
        }
    }

    private var confirmationScreen: some View {
        VStack(spacing: 0) {
            screenHeader

            DDProgressBar(currentStep: 3)
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.xxLarge)

            ScrollView {
                VStack(alignment: .leading, spacing: DDSpacing.medium) {
                    Text("이대로 넣어둘까요?")
                        .ddTypography(.heading18)
                        .foregroundStyle(DDColor.textPrimary)
                        .padding(.bottom, DDSpacing.xSmall)

                    flightNumberCard(
                        title: "편명",
                        flightNumber: store.outbound.flightNumber,
                        editAction: { store.send(.flightNumberEditButtonTapped(.outbound)) },
                        removeAction: { store.send(.flightNumberRemoveButtonTapped) }
                    )

                    dateCard(
                        title: "가는 날",
                        date: store.outbound.departureDate,
                        editAction: { store.send(.departureDateEditButtonTapped(.outbound)) }
                    )

                    if let returnFlight = store.returnFlight {
                        flightNumberCard(
                            title: "돌아오는 편명",
                            flightNumber: returnFlight.flightNumber,
                            editAction: { store.send(.flightNumberEditButtonTapped(.returnFlight)) },
                            removeAction: { store.send(.returnFlightRemoveButtonTapped) }
                        )
                        dateCard(
                            title: "돌아오는 날",
                            date: returnFlight.departureDate,
                            editAction: { store.send(.departureDateEditButtonTapped(.returnFlight)) }
                        )
                    } else {
                        addReturnFlightButton
                    }

                    reservationNumberField
                        .padding(.top, DDSpacing.xSmall)

                    voucherSection
                        .padding(.top, 56)
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.large)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DDCTAButton(
                title: "항공권 추가하기",
                style: store.isRegistrationEnabled ? .primary : .secondary,
                isEnabled: store.isRegistrationEnabled
            ) {
                store.send(.addFlightButtonTapped)
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
                Text("항공권을 등록하게따")
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

    private var flightNumberField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("편명")
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)

            TextField(
                "",
                text: Binding(
                    get: { store.flightNumberInput },
                    set: { store.send(.flightNumberChanged($0)) }
                )
            )
            .ddTypography(.body16)
            .foregroundStyle(DDColor.textPrimary)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .submitLabel(.done)
            .focused($isFlightNumberFocused)
            .onSubmit {
                isFlightNumberFocused = false
            }
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .frame(height: 68)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: DDRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderSubtle, lineWidth: 1)
        }
    }

    private var addReturnFlightButton: some View {
        Button {
            store.send(.returnFlightAddButtonTapped)
        } label: {
            HStack(spacing: DDSpacing.medium) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .regular))

                Text("돌아오는 편 추가")
                    .ddTypography(.label14)
            }
            .foregroundStyle(DDColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: DDRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DDRadius.medium)
                    .stroke(DDColor.borderSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var reservationNumberField: some View {
        TextField(
            "",
            text: Binding(
                get: { store.reservationNumber },
                set: { store.send(.reservationNumberChanged($0)) }
            ),
            prompt: Text("(선택) 예약번호")
                .foregroundStyle(DDColor.textSecondary)
        )
        .ddTypography(.body16)
        .foregroundStyle(DDColor.textPrimary)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
        .padding(.horizontal, DDSpacing.xLarge)
        .frame(height: 68)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: DDRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderSubtle, lineWidth: 1)
        }
    }

    private var voucherSection: some View {
        VStack(alignment: .leading, spacing: DDSpacing.large) {
            Text("넣어두면 필요할 때 바로 꺼내 볼 수 있어요")
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)

            Group {
                if let fileName = store.voucherFileName {
                    HStack(spacing: 0) {
                        Button {
                            store.send(.voucherAreaTapped)
                        } label: {
                            HStack(spacing: DDSpacing.medium) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 24))

                                Text(fileName)
                                    .ddTypography(.label14)
                                    .lineLimit(2)

                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(DDColor.textPrimary)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.send(.voucherRemoveButtonTapped)
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(DDColor.textPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("바우처 첨부 삭제")
                    }
                    .padding(DDSpacing.xLarge)
                } else {
                    Button {
                        store.send(.voucherAreaTapped)
                    } label: {
                        VStack(spacing: DDSpacing.large) {
                            Image(systemName: "plus")
                                .font(.system(size: 30, weight: .light))

                            Text("바우처를 담아두면\n입장할 때 바로 꺼낼 수 있어요")
                                .ddTypography(.label14)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(DDColor.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: DDRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DDRadius.medium)
                    .stroke(DDColor.borderSubtle, lineWidth: 1)
            }
        }
    }

    private func flightNumberCard(
        title: String,
        flightNumber: String,
        editAction: @escaping () -> Void,
        removeAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DDSpacing.medium) {
            Button(action: editAction) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .ddTypography(.caption12)
                        .foregroundStyle(DDColor.textSecondary)

                    Text(flightNumber)
                        .ddTypography(.body16)
                        .foregroundStyle(DDColor.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) 수정")

            Button(action: removeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) 삭제")
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .frame(minHeight: 68)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: DDRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderSubtle, lineWidth: 1)
        }
    }

    private func dateCard(
        title: String,
        date: Date?,
        editAction: @escaping () -> Void
    ) -> some View {
        Button(action: editAction) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)

                Text(date.map(formattedDate) ?? "-")
                    .ddTypography(.body16)
                    .foregroundStyle(DDColor.textPrimary)
            }
            .padding(.horizontal, DDSpacing.xLarge)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) 수정")
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: DDRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderSubtle, lineWidth: 1)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M.dd E"
        return formatter.string(from: date)
    }
}

#Preview("편명 입력") {
    TripSetUpAddFlightView(
        store: Store(initialState: TripSetUpAddFlightFeature.State()) {
            TripSetUpAddFlightFeature()
        }
    )
}
