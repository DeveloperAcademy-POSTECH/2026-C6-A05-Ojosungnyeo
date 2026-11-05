//
//  WaitingForParticipantsView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct WaitingForParticipantsView: View {
    let store: StoreOf<WaitingForParticipantsFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DDSpacing.zero) {
                header

                Text("초대 링크를 친구에게 공유해 주세요.\n72시간 안에 가고 싶은 장소를 저장하세요.")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineSpacing(2)
                    .padding(.top, DDSpacing.small)

                invitationCard
                    .padding(.top, DDSpacing.xxLarge + DDSpacing.large)

                timer
                    .frame(maxWidth: .infinity)
                    .padding(.top, 108)

                participantsCard
                    .padding(.top, 98)

                if !store.haveAllParticipantsJoined {
                    refreshButton
                        .frame(maxWidth: .infinity)
                        .padding(.top, DDSpacing.xSmall)
                }
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.bottom, DDSpacing.xLarge)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: DDSpacing.zero) {
            DDCTAButton(title: "지도에 핀 찍으러 가기") {
                store.send(.mapButtonTapped)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, DDSpacing.medium)
            .padding(.bottom, 11)
            .background(DDColor.surfaceDefault)
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .navigationDestination(
            isPresented: Binding(
                get: { store.isPlaceSelectionPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.placeSelectionDismissed)
                    }
                }
            )
        ) {
            PlaceSelectionView(
                store: store.scope(
                    state: \.placeSelection,
                    action: \.placeSelection
                )
            )
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .allowsHitTesting(!store.isMapConfirmationPresented)
        .overlay {
            if store.isMapConfirmationPresented {
                ZStack {
                    Color.black
                        .opacity(0.55)
                        .ignoresSafeArea()

                    DDConfirmationAlert(
                        title: "먼저 여행 준비하기",
                        message: "지도에 핀을 찍으러 이동하시겠어요?",
                        cancelTitle: "아니요",
                        confirmTitle: "네",
                        onCancel: { store.send(.mapConfirmationCancelButtonTapped) },
                        onConfirm: { store.send(.mapConfirmationConfirmButtonTapped) }
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
                    .frame(width: 24, height: 35)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로 가기")

            HStack(spacing: DDSpacing.xSmall) {
                Text("친구를 기다리고 이따")
                    .ddTypography(.title24)
                    .foregroundStyle(DDColor.textPrimary)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: DDSpacing.zero)
        }
        .frame(height: 35)
    }

    private var invitationCard: some View {
        VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
            Text("초대 코드")
                .ddTypography(.captionEmphasis12)
                .foregroundStyle(DDColor.textPrimary)

            HStack(alignment: .center) {
                Text(store.invitation.code)
                    .ddTypography(.title24)
                    .foregroundStyle(DDColor.textPrimary)
                    .underline()

                Spacer(minLength: DDSpacing.small)

                ShareLink(
                    item: store.invitation.shareText,
                    preview: SharePreview(
                        "따또 여행 초대 링크",
                        image: Image("DDInvitationSharePreview")
                    )
                ) {
                    Text("공유하기")
                        .ddTypography(.labelEmphasis14)
                        .foregroundStyle(DDColor.textOnPrimary)
                        .padding(.horizontal, DDSpacing.medium)
                        .frame(height: 30)
                        .background(DDColor.actionPrimary)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.vertical, DDSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private var timer: some View {
        Text(timerDisplayText)
            .font(.custom("Pretendard-SemiBold", size: 36, relativeTo: .largeTitle))
            .foregroundStyle(DDColor.actionPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .multilineTextAlignment(.center)
    }

    private var timerDisplayText: String {
        let remainingSeconds = store.remainingSeconds
        guard remainingSeconds > 0 else { return "초대 기간이 만료되었어요" }

        let hours = remainingSeconds / 3_600
        let minutes = remainingSeconds % 3_600 / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분 남음"
        }
        return minutes > 0 ? "\(minutes)분 남음" : "1분 미만 남음"
    }

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: DDSpacing.medium) {
            HStack {
                Text("함께하는 친구")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)

                Spacer()

                Text("\(store.joinedCount)/\(store.invitation.participants.count) 참여 완료")
                    .ddTypography(.captionEmphasis12)
                    .foregroundStyle(DDColor.actionPrimary)
            }
            .frame(height: 24)

            HStack(spacing: DDSpacing.small) {
                ForEach(store.invitation.participants) { participant in
                    participantProfile(participant)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .top)
        }
        .padding(.leading, 17)
        .padding(.trailing, 15)
        .padding(.top, 17)
        .padding(.bottom, 17)
        .frame(maxWidth: .infinity, minHeight: 181, alignment: .topLeading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: DDRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private func participantProfile(_ participant: WaitingForParticipantsFeature.Participant) -> some View {
        VStack(spacing: DDSpacing.xSmall) {
            if participant.hasJoined {
                ZStack {
                    Circle()
                        .fill(avatarBackgroundColor(for: participant.avatarName))

                    if let avatarName = participant.avatarName,
                       let character = DDMiniHeadAvatar.Character(rawValue: avatarName) {
                        Image(character.rawValue)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 44)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DDColor.textPrimary)
                    }
                }
                .frame(width: 56, height: 56)
            } else {
                ZStack {
                    Circle()
                        .stroke(DDColor.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    Image(systemName: "person")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(DDColor.textPrimary)
                }
                .frame(width: 56, height: 56)
            }

            VStack(spacing: 6) {
                Text(participant.displayName)
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: 20)

                Text(participant.hasJoined ? "참여 완료" : "참여 대기")
                    .ddTypography(.caption12)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(1)
                    .frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .top)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func avatarBackgroundColor(for avatarName: String?) -> Color {
        guard let avatarName,
              let character = ParticipantAvatar(rawValue: avatarName)
        else { return DDColor.avatarBackground }

        return character.backgroundColor
    }

    private var refreshButton: some View {
        Button {
            store.send(.refreshTapped)
        } label: {
            HStack(spacing: DDSpacing.xSmall) {
                if store.isRefreshing {
                    ProgressView()
                        .tint(DDColor.textSecondary)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text("참여 현황 새로고침")
                    .ddTypography(.label14)
            }
            .foregroundStyle(DDColor.textSecondary)
            .frame(height: 26)
        }
        .buttonStyle(.plain)
        .disabled(store.isRefreshing)
    }
}

#Preview {
    WaitingForParticipantsView(
        store: Store(initialState: .mock()) {
            WaitingForParticipantsFeature()
        }
    )
}
