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

                    ScrollView {
                        VStack(spacing: 0) {
                            tripSummary
                            setUpCards
                                .padding(.top, DDSpacing.large)
                        }
                        .padding(.horizontal, DDSpacing.large)
                        .padding(.top, 5)
                        .padding(.bottom, DDSpacing.large)
                    }
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomActionArea
                }
            }
            .background(DDColor.surfaceDefault.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .navigationDestination(
                isPresented: Binding(
                    get: { store.isWaitingForParticipantsPresented },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.waitingForParticipantsDismissed)
                        }
                    }
                )
            ) {
                if let waitingStore = store.scope(
                    state: \.waitingForParticipants,
                    action: \.waitingForParticipants
                ) {
                    WaitingForParticipantsView(store: waitingStore)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { store.isDatePickerPresented },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.tripDatePickerCloseButtonTapped)
                        }
                    }
                )
            ) {
                TripDatePickerView(
                    selectedStartDate: store.draftStartDate,
                    selectedEndDate: store.draftEndDate,
                    onDateSelected: { store.send(.tripDateTapped($0)) },
                    onClose: { store.send(.tripDatePickerCloseButtonTapped) },
                    onConfirm: { store.send(.tripDatePickerConfirmButtonTapped) }
                )
                .presentationDetents([.height(526)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(36)
                .presentationBackground(DDColor.surfaceDefault)
            }
            .sheet(
                isPresented: Binding(
                    get: { store.isTransportationSheetPresented },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.transportationSheetDismissed)
                        }
                    }
                )
            ) {
                TripSetUpTransportationView(
                    store: store.scope(
                        state: \.transportationSheet,
                        action: \.transportationSheet
                    )
                )
                .presentationDetents([.height(524)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
                .presentationBackground(DDColor.surfaceDefault)
            }
        }
        .allowsHitTesting(!store.isConfirmationAlertPresented)
        .overlay {
            if store.isConfirmationAlertPresented {
                ZStack {
                    Color.black
                        .opacity(0.55)
                        .ignoresSafeArea()

                    DDConfirmationAlert(
                        title: "친구를 초대할까요?",
                        message: "여행 계획을 위한 모든 준비가 끝났어요.\n친구를 초대하러 가시겠어요?",
                        cancelTitle: "아니요",
                        confirmTitle: "네",
                        onCancel: { store.send(.confirmationCancelButtonTapped) },
                        onConfirm: { store.send(.confirmationConfirmButtonTapped) }
                    )
                }
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

            Text("여행 정보 추가")
                .ddTypography(.title24)
                .foregroundStyle(DDColor.textPrimary)

            Spacer()
        }
        .frame(height: 52)
    }

    private var tripSummary: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(store.tripTitle)
                .ddTypography(.heading20)
                .foregroundStyle(DDColor.textPrimary)

            Text(store.destinationSummary)
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(.top, 3)
        .frame(maxWidth: .infinity, minHeight: 57, alignment: .topLeading)
    }

    private var setUpCards: some View {
        VStack(spacing: DDSpacing.medium) {
            navigationCard(title: "여행 일정", detail: store.tripDateSummary, height: 83) {
                store.send(.travelScheduleButtonTapped)
            }

            travelerCard

            navigationCard(
                title: "이동 수단",
                detail: store.transportationSummary,
                detailColor: DDColor.actionPrimary,
                height: 95
            ) {
                store.send(.transportationCardTapped)
            }
        }
    }

    private var travelerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("여행 인원")
                .ddTypography(.heading18)
                .foregroundStyle(DDColor.textPrimary)

            HStack(spacing: DDSpacing.small) {
                Button {
                    store.send(.travelerDecreaseButtonTapped)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(store.travelerCount == 1)
                .foregroundStyle(DDColor.textPrimary)
                .accessibilityLabel("여행 인원 줄이기")

                Text("\(store.travelerCount)명")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.actionPrimary)
                    .frame(width: 64)

                Button {
                    store.send(.travelerIncreaseButtonTapped)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(store.travelerCount == TripSetUpFeature.State.maximumTravelerCount)
                .foregroundStyle(DDColor.textPrimary)
                .accessibilityLabel("여행 인원 늘리기")
            }
        }
        .padding(DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private var bottomActionArea: some View {
        Button {
            store.send(.saveButtonTapped)
        } label: {
            Text("친구 초대하러 가기")
                .ddTypography(.heading20)
                .foregroundStyle(DDColor.textOnPrimary)
                .frame(maxWidth: .infinity, minHeight: 55)
                .background(store.isSaveEnabled ? DDColor.actionPrimary : DDColor.textTertiary)
                .clipShape(.rect(cornerRadius: DDRadius.medium))
        }
        .buttonStyle(.plain)
        .disabled(!store.isSaveEnabled)
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, DDSpacing.xLarge)
        .padding(.bottom, 11)
        .background(DDColor.surfaceDefault)
    }

    private func navigationCard(
        title: String,
        detail: String? = nil,
        detailColor: Color = DDColor.textSecondary,
        height: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DDSpacing.small) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .ddTypography(.heading18)
                        .foregroundStyle(DDColor.textPrimary)

                    if let detail {
                        Text(detail)
                            .ddTypography(.label14)
                            .foregroundStyle(detailColor)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(height: 50)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DDColor.borderDefault, lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TripSetUpView(
        store: Store(initialState: TripSetUpFeature.State()) {
            TripSetUpFeature()
        }
    )
}
