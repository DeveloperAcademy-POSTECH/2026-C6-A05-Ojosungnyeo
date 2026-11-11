//
//  UpcomingTripsView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct UpcomingTripsView: View {
    let store: StoreOf<UpcomingTripsFeature>
    @State private var openSwipeTripID: UpcomingTripsFeature.Trip.ID?

    var body: some View {
        ZStack {
            DDColor.surfaceDefault
                .ignoresSafeArea()

            VStack(spacing: 0) {
                UpcomingTripsBroadcastBanner(
                    message: "한 달 내로\n여행 일정이 이따!"
                )
                    .padding(.horizontal, DDSpacing.large)
                    .padding(.top, DDSpacing.small)
                    .padding(.bottom, 8)

                if store.trips.isEmpty && !store.isLoadingTrips {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(store.trips) { trip in
                                SwipeableUpcomingTripCard(
                                    trip: trip,
                                    openTripID: $openSwipeTripID,
                                    deleteAction: {
                                        store.send(.deleteButtonTapped(trip.id))
                                    },
                                    action: {
                                        store.send(.viewScheduleButtonTapped(trip.id))
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, DDSpacing.large)
                        .padding(.top, 15)
                        .padding(.bottom, DDSpacing.xLarge)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .padding(.horizontal, DDSpacing.small)
                    .padding(.bottom, DDSpacing.small)
                    .background(DDColor.surfaceDefault)
            }
        }
        .overlay {
            if store.isAddTripMenuPresented {
                GeometryReader { _ in
                    ZStack(alignment: .topTrailing) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.send(.addTripMenuDismissed)
                            }

                        addTripMenu
                            .padding(.trailing, DDSpacing.large)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isAddTripMenuPresented)
        .task {
            store.send(.onAppear)
        }
        .overlay {
            if store.isInviteCodeModalPresented {
                ZStack {
                    Color.black
                        .opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
                            store.send(.inviteCodeModalDismissed)
                        }

                    InviteCodeModal(
                        code: Binding(
                            get: { store.inviteCode },
                            set: { store.send(.inviteCodeChanged($0)) }
                        ),
                        cancelAction: {
                            store.send(.inviteCodeModalDismissed)
                        },
                        joinAction: {
                            store.send(.joinTripButtonTapped)
                        }
                    )
                }
                .transition(.opacity)
            }

            if store.isWaitingForParticipantsPresented,
               let waitingStore = store.scope(
                   state: \.waitingForParticipants,
                   action: \.waitingForParticipants
               ) {
                NavigationStack {
                    WaitingForParticipantsView(store: waitingStore)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isInviteCodeModalPresented)
        .animation(.easeInOut(duration: 0.3), value: store.isWaitingForParticipantsPresented)
        .allowsHitTesting(
            store.pendingDeletionTripID == nil
                && store.joinErrorMessage == nil
                && store.deletionErrorMessage == nil
        )
        .overlay {
            if store.pendingDeletionTripID != nil {
                DDAlertOverlay(
                    title: "여행을 삭제할까요?",
                    message: "삭제한 여행은 예정된 여행 목록에서 사라져요.",
                    cancelTitle: "아니요",
                    confirmTitle: "네",
                    confirmColor: DDColor.alertDestructive,
                    onCancel: { store.send(.deleteCancelButtonTapped) },
                    onConfirm: { store.send(.deleteConfirmButtonTapped) }
                )
            } else if let message = store.joinErrorMessage {
                DDAlertOverlay(
                    title: joinAlertTitle(for: message),
                    message: joinAlertMessage(for: message),
                    confirmTitle: "확인",
                    onConfirm: { store.send(.joinErrorDismissed) }
                )
            } else if let message = store.deletionErrorMessage {
                DDAlertOverlay(
                    title: "여행을 삭제하지 못했어요",
                    message: message,
                    confirmTitle: "확인",
                    onConfirm: { store.send(.deletionErrorDismissed) }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private func joinAlertTitle(for message: String) -> String {
        isCapacityError(message) ? "초대 인원이 모두 찼어요" : "여행에 참여할 수 없어요"
    }

    private func joinAlertMessage(for message: String) -> String {
        if isCapacityError(message) {
            return "이 여행은 정원이 가득 차 참여할 수 없어요.\n초대한 친구에게 확인해 주세요."
        }
        return message
    }

    private func isCapacityError(_ message: String) -> Bool {
        message == TripServiceError.tripIsFull.errorDescription
    }

    private var emptyState: some View {
        VStack(spacing: DDSpacing.small) {
            Text("아직 예정된 여행이 없어따.")
                .ddTypography(.heading20)
                .foregroundStyle(DDColor.textPrimary)

            Text("+를 눌러 친구들과 여행 계획을 세워보세따!")
                .ddTypography(.body16)
                .foregroundStyle(DDColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DDSpacing.large)
    }

    private var header: some View {
        HStack(spacing: DDSpacing.small) {
            DDBackButton(accessibilityLabel: "홈으로 돌아가기") {
                store.send(.backButtonTapped)
            }

            Text("예정된 여행")
                .ddTypography(.title24)
                .foregroundStyle(DDColor.textPrimary)

            Spacer(minLength: 0)

            headerButton(
                systemName: "plus",
                accessibilityLabel: "여행 추가",
                action: { store.send(.addTripButtonTapped) }
            )
        }
        .frame(height: 44)
    }

    private func headerButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(DDColor.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var addTripMenu: some View {
        VStack(spacing: 0) {
            addTripMenuButton("방 생성하기") {
                store.send(.createTripButtonTapped)
            }

            Rectangle()
                .fill(Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255))
                .frame(height: 1)

            addTripMenuButton("초대 코드 입력하기") {
                store.send(.enterInviteCodeButtonTapped)
            }
        }
        .frame(width: 180)
        .background(Color.black)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .contain)
    }

    private func addTripMenuButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, DDSpacing.large)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

private struct SwipeableUpcomingTripCard: View {
    let trip: UpcomingTripsFeature.Trip
    @Binding var openTripID: UpcomingTripsFeature.Trip.ID?
    let deleteAction: () -> Void
    let action: () -> Void

    @State private var dragTranslation: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let deleteWidth = proxy.size.width * (CGFloat(121) / 370)
            let revealWidth = deleteWidth + 15
            let openOffset = openTripID == trip.id ? -revealWidth : 0
            let cardOffset = min(0, max(-revealWidth, openOffset + dragTranslation))

            ZStack(alignment: .trailing) {
                Button(action: deleteAction) {
                    Image(systemName: "trash")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(DDColor.actionPrimary)
                        .frame(width: deleteWidth, height: proxy.size.height)
                        .background(Color(red: 68 / 255, green: 68 / 255, blue: 68 / 255))
                        .clipShape(.rect(cornerRadius: DDRadius.medium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(trip.destination) 여행 삭제")

                UpcomingTripTicketCard(trip: trip, action: action)
                    .frame(width: proxy.size.width)
                    .offset(x: cardOffset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                dragTranslation = value.translation.width
                            }
                            .onEnded { value in
                                defer { dragTranslation = 0 }
                                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    openTripID = value.translation.width < -40 ? trip.id : nil
                                }
                            }
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(377.6288757324219 / 146, contentMode: .fit)
    }
}

private struct UpcomingTripsBroadcastBanner: View {
    let message: String

    var body: some View {
        Image("DDUpcomingTripsBroadcast")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { proxy in
                    let bannerScale = proxy.size.width / 370

                    Text(message)
                        .ddTypography(.captionEmphasis12)
                        .tracking(0.6)
                        .lineSpacing(2)
                        .foregroundStyle(DDColor.textOnPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(
                            width: 96 * bannerScale,
                            height: 40 * bannerScale,
                            alignment: .leading
                        )
                        .background(Color.white)
                        .position(
                            x: proxy.size.width * 0.744,
                            y: proxy.size.height * 0.32
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
    }
}

private struct UpcomingTripTicketCard: View {
    let trip: UpcomingTripsFeature.Trip
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let trailingWidth = proxy.size.width * 0.378
            let leadingWidth = proxy.size.width - trailingWidth

            ZStack {
                ticketBackground(
                    width: proxy.size.width,
                    trailingWidth: trailingWidth
                )

                Image("DDHomeTripCardMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask {
                        ZStack {
                            Color.white

                            Rectangle()
                                .frame(width: 54, height: 48)
                                .position(x: leadingWidth - 25, y: 48)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                    .allowsHitTesting(false)

                Image(systemName: "airplane")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(DDColor.surfaceControl)
                    .rotationEffect(.degrees(-20))
                    .position(x: leadingWidth - 25, y: 48)
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: DDSpacing.small) {
                        Text(trip.dateText)
                            .ddTypography(.label14)
                            .foregroundStyle(DDColor.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text(trip.progressTitle)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.surfaceControl)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    HStack(alignment: .bottom, spacing: DDSpacing.small) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(trip.destination)
                                .ddTypography(.title28)
                                .foregroundStyle(DDColor.surfaceSelected)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text(trip.country)
                                .ddTypography(.body16)
                                .foregroundStyle(DDColor.textSecondary)
                        }

                        Spacer(minLength: 0)

                        Button("바로가기", action: action)
                            .ddTypography(.bodyEmphasis16)
                            .foregroundStyle(DDColor.textPrimary)
                            .padding(.horizontal, DDSpacing.large)
                            .frame(height: 40)
                            .background(DDColor.surfaceControl)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.vertical, DDSpacing.medium)
            }
        }
        .aspectRatio(377.6288757324219 / 146, contentMode: .fit)
    }

    private func ticketBackground(
        width: CGFloat,
        trailingWidth: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            Color(red: 96 / 255, green: 96 / 255, blue: 96 / 255)
                .frame(width: width - trailingWidth)

            DDColor.surfaceSelected
                .frame(width: trailingWidth)
        }
        .clipShape(.rect(cornerRadius: 20))
    }
}

#Preview {
    UpcomingTripsView(
        store: Store(initialState: UpcomingTripsPreviewData.state) {
            UpcomingTripsFeature()
        }
    )
}
