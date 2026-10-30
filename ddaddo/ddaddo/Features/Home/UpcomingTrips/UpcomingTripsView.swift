//
//  UpcomingTripsView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct UpcomingTripsView: View {
    let store: StoreOf<UpcomingTripsFeature>

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

                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(store.trips) { trip in
                            UpcomingTripTicketCard(
                                trip: trip,
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
        .preferredColorScheme(.dark)
        .alert(
            "여행에 참여할 수 없어요",
            isPresented: Binding(
                get: { store.joinErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.joinErrorDismissed)
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                store.send(.joinErrorDismissed)
            }
        } message: {
            Text(store.joinErrorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerButton(
                systemName: "chevron.left",
                accessibilityLabel: "홈으로 돌아가기",
                action: { store.send(.backButtonTapped) }
            )

            Text("예정된 여행")
                .ddTypography(.title24)
                .foregroundStyle(DDColor.textPrimary)

            Spacer(minLength: DDSpacing.small)

            headerButton(
                systemName: "plus",
                accessibilityLabel: "여행 추가",
                action: { store.send(.addTripButtonTapped) }
            )
        }
        .frame(height: 52)
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

private struct UpcomingTripsBroadcastBanner: View {
    let message: String

    var body: some View {
        Image("DDUpcomingTripsBroadcast")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { proxy in
                    Text(message)
                        .ddTypography(.labelEmphasis14)
                        .tracking(0.6)
                        .lineSpacing(2)
                        .foregroundStyle(DDColor.textOnPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(width: 96, height: 40, alignment: .leading)
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
                        Label("Flight Ticket", systemImage: "airplane.ticket.fill")
                            .ddTypography(.heading20)
                            .foregroundStyle(DDColor.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text(trip.dateText)
                            .ddTypography(.label14)
                            .foregroundStyle(
                                Color(
                                    red: 96 / 255,
                                    green: 96 / 255,
                                    blue: 96 / 255
                                )
                            )
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
