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
                        .padding(.horizontal, DDSpacing.small)

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
        .allowsHitTesting(
            !store.isConfirmationAlertPresented && store.creationErrorMessage == nil
        )
        .overlay {
            if store.isConfirmationAlertPresented {
                DDAlertOverlay(
                    title: "친구를 초대할까요?",
                    message: "여행 계획을 위한 모든 준비가 끝났어요.\n친구를 초대하러 가시겠어요?",
                    cancelTitle: "아니요",
                    confirmTitle: "네",
                    onCancel: { store.send(.confirmationCancelButtonTapped) },
                    onConfirm: { store.send(.confirmationConfirmButtonTapped) }
                )
            } else if let message = store.creationErrorMessage {
                DDAlertOverlay(
                    title: "여행을 만들지 못했어요",
                    message: message,
                    confirmTitle: "확인",
                    onConfirm: { store.send(.creationErrorDismissed) }
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: DDSpacing.small) {
            DDBackButton(accessibilityLabel: "뒤로 가기") {
                store.send(.backButtonTapped)
            }

            Text("여행 정보 추가")
                .ddTypography(.title24)
                .foregroundStyle(DDColor.textPrimary)

            Spacer()
        }
        .frame(height: 44)
    }

    private var tripSummary: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(store.tripTitle)
                .ddTypography(.heading20)
                .foregroundStyle(DDColor.textPrimary)
                .frame(height: 30, alignment: .topLeading)

            Text(store.destinationSummary)
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
                .frame(height: 18, alignment: .topLeading)
        }
        .frame(height: 52, alignment: .topLeading)
        .padding(.top, DDSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 68, alignment: .topLeading)
    }

    private var setUpCards: some View {
        VStack(spacing: DDSpacing.medium) {
            navigationCard(
                title: "여행 일정",
                detail: store.tripDateSummary,
                detailColor: DDColor.actionPrimary,
                height: 83
            ) {
                store.send(.travelScheduleButtonTapped)
            }

            travelerCard

            navigationCard(
                title: "이동 수단",
                detail: store.transportationSummary,
                detailColor: DDColor.actionPrimary,
                height: 83
            ) {
                store.send(.transportationCardTapped)
            }
        }
    }

    private var travelerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("여행 인원")
                .ddTypography(.heading18)
                .foregroundStyle(DDColor.textPrimary)
                .frame(height: 24, alignment: .leading)

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
                    .frame(width: 64, height: 20)

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
        .padding(.leading, 16.5)
        .padding(.trailing, 15.5)
        .padding(.top, 14.5)
        .frame(maxWidth: .infinity, minHeight: 95, maxHeight: 95, alignment: .topLeading)
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
            Text(store.isCreatingTrip ? "여행 만드는 중..." : "친구 초대하러 가기")
                .ddTypography(.heading20)
                .foregroundStyle(DDColor.textOnPrimary)
                .frame(maxWidth: .infinity, minHeight: 55)
                .background(store.isSaveEnabled ? DDColor.actionPrimary : DDColor.textTertiary)
                .clipShape(.rect(cornerRadius: DDRadius.medium))
        }
        .buttonStyle(.plain)
        .disabled(!store.isSaveEnabled || store.isCreatingTrip)
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
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .ddTypography(.heading18)
                        .foregroundStyle(DDColor.textPrimary)
                        .frame(height: 24, alignment: .leading)

                    if let detail {
                        Text(detail)
                            .ddTypography(.label14)
                            .foregroundStyle(detailColor)
                            .frame(height: 20, alignment: .leading)
                    }
                }
                .padding(.top, 14.5)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 24, height: 24)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(.leading, 16.5)
            .padding(.trailing, 15.5)
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

#Preview("TripSetUpView_AddTravel_2") {
    TripSetUpView(
        store: Store(initialState: TripSetUpFeature.State(selectedCities: [.previewTokyo])) {
            TripSetUpFeature()
        }
    )
}

private extension TripDestination {
    static let previewTokyo = TripDestination(
        id: "preview-tokyo",
        country: "일본",
        name: "도쿄",
        region: .asia,
        thumbnailName: "",
        sortOrder: 0
    )
}
