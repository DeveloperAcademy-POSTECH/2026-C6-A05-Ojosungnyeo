//
//  TripSetUpView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct TripSetUpView: View {
    let store: StoreOf<TripSetUpFeature>

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, DDSpacing.large)

                    DDProgressBar(currentStep: 2)
                        .padding(.horizontal, DDSpacing.large)
                        .padding(.bottom, DDSpacing.xxLarge)

                    ScrollView {
                        VStack(spacing: 0) {
                            tripSummary
                            setUpCards
                                .padding(.top, 28)
                        }
                        .padding(.horizontal, DDSpacing.large)
                        .padding(.bottom, DDSpacing.large)
                    }
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomActionArea
                }

                if store.isDatePickerPresented {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()

                    TripDatePickerView(
                        selectedStartDate: store.draftStartDate,
                        selectedEndDate: store.draftEndDate,
                        onDateSelected: { store.send(.tripDateTapped($0)) },
                        onClose: { store.send(.tripDatePickerCloseButtonTapped) },
                        onConfirm: { store.send(.tripDatePickerConfirmButtonTapped) }
                    )
                    .frame(maxHeight: 710)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isDatePickerPresented)
            .background(DDColor.surfaceDefault.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .navigationDestination(
                isPresented: Binding(
                    get: { store.isAddFlightPresented },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.addFlightDismissed)
                        }
                    }
                )
            ) {
                TripSetUpAddFlightView(
                    store: store.scope(
                        state: \.addFlight,
                        action: \.addFlight
                    )
                )
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { store.isAddAccommodationPresented },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.addAccommodationDismissed)
                        }
                    }
                )
            ) {
                TripSetUpAddAccommodationView(
                    store: store.scope(
                        state: \.addAccommodation,
                        action: \.addAccommodation
                    )
                )
            }
        }
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
                    .contentShape(.rect)
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

    private var tripSummary: some View {
        HStack(spacing: DDSpacing.large) {
            VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
                Text(store.tripTitle)
                    .ddTypography(.heading20)
                    .foregroundStyle(DDColor.textPrimary)

                Text(store.destinationSummary)
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
            }

            Spacer(minLength: 0)

            DDCTAButton(
                title: "여행지 변경",
                style: .secondary,
                layout: .compact
            ) {
                store.send(.destinationChangeButtonTapped)
            }
        }
    }

    private var setUpCards: some View {
        VStack(spacing: DDSpacing.medium) {
            navigationCard(
                title: "여행 일정",
                detail: store.tripDateSummary,
                isRequired: true
            ) {
                store.send(.travelScheduleButtonTapped)
            }

            travelerCard

            navigationCard(title: "항공권 정보", detail: store.flightSummary) {
                store.send(.flightInfoButtonTapped)
            }

            navigationCard(title: "숙소 정보", detail: store.accommodationSummary) {
                store.send(.accommodationInfoButtonTapped)
            }
        }
    }

    private var travelerCard: some View {
        VStack(alignment: .leading, spacing: DDSpacing.large) {
            requiredTitle("여행 인원")

            HStack(spacing: 28) {
                Button {
                    store.send(.travelerDecreaseButtonTapped)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(store.travelerCount == 1)
                .foregroundStyle(
                    store.travelerCount == 1
                        ? DDColor.textTertiary
                        : DDColor.textPrimary
                )
                .accessibilityLabel("여행 인원 줄이기")

                Text("\(store.travelerCount)명")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textSecondary)

                Button {
                    store.send(.travelerIncreaseButtonTapped)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(store.travelerCount == TripSetUpFeature.State.maximumTravelerCount)
                .foregroundStyle(
                    store.travelerCount == TripSetUpFeature.State.maximumTravelerCount
                        ? DDColor.textTertiary
                        : DDColor.textPrimary
                )
                .accessibilityLabel("여행 인원 늘리기")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: DDRadius.medium))
    }

    private var bottomActionArea: some View {
        VStack(spacing: DDSpacing.medium) {
            Button {
                store.send(.inviteFriendButtonTapped)
            } label: {
                Text("친구 초대하기")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
            }
            .buttonStyle(.plain)

            DDCTAButton(
                title: "이 일정으로 저장",
                style: store.isSaveEnabled ? .primary : .secondary,
                isEnabled: store.isSaveEnabled
            ) {
                store.send(.saveButtonTapped)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, DDSpacing.medium)
        .padding(.bottom, DDSpacing.medium)
        .background(DDColor.surfaceDefault)
    }

    private func navigationCard(
        title: String,
        detail: String? = nil,
        isRequired: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DDSpacing.small) {
                HStack(spacing: DDSpacing.xSmall) {
                    Text(title)
                        .ddTypography(.heading18)
                        .foregroundStyle(DDColor.textPrimary)

                    if isRequired {
                        Text("*")
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.actionPrimary)
                    }

                    if let detail {
                        Text(detail)
                            .ddTypography(.caption12)
                            .foregroundStyle(DDColor.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
            }
            .padding(.horizontal, DDSpacing.large)
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: DDRadius.medium))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func requiredTitle(_ title: String) -> some View {
        HStack(spacing: DDSpacing.xSmall) {
            Text(title)
                .ddTypography(.heading18)

            Text("*")
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.actionPrimary)
        }
        .foregroundStyle(DDColor.textPrimary)
    }
}

#Preview {
    TripSetUpView(
        store: Store(initialState: TripSetUpFeature.State()) {
            TripSetUpFeature()
        }
    )
}
