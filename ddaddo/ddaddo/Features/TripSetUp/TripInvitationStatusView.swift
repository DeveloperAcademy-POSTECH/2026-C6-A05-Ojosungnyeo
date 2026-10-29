//
//  TripInvitationStatusView.swift
//  ddaddo
//

import SwiftUI
import UIKit

struct TripInvitationStatusView: View {
    enum ScreenState: Equatable {
        case hostWaiting
        case nicknameEntry
        case friendWaiting
        case allJoined
    }

    enum PresentedSheet: Equatable {
        case invite
        case remind
        case reminded
    }

    let screenState: ScreenState

    @Environment(\.dismiss) private var dismiss

    @State private var activeSheet: PresentedSheet?
    @State private var joinedCount: Int
    @State private var nickname = ""
    @State private var reminderTargetName = "그레"
    @State private var hasCopiedInviteLink = false
    @State private var showsSetupOverview = false

    private let mockInviteLink = "ddaddo://invite/TG8C5H"

    init(
        screenState: ScreenState,
        presentedSheet: PresentedSheet? = nil
    ) {
        self.screenState = screenState
        _activeSheet = State(initialValue: presentedSheet)
        _joinedCount = State(
            initialValue: Self.initialJoinedCount(
                for: screenState,
                presentedSheet: presentedSheet
            )
        )
    }

    var body: some View {
        ZStack {
            if showsSetupOverview {
                TripSetupOverviewView(onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsSetupOverview = false
                    }
                })
                .transition(.move(edge: .trailing))
            } else {
                invitationStatus
                    .transition(.move(edge: .leading))
            }
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .foregroundStyle(DDColor.textPrimary)
    }

    private var invitationStatus: some View {
        ZStack(alignment: .bottom) {
            content

            if let activeSheet {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSheet()
                    }

                TripInvitationBottomSheet(
                    style: activeSheet,
                    reminderTargetName: reminderTargetName,
                    hasCopiedInviteLink: hasCopiedInviteLink,
                    onDismiss: dismissSheet,
                    onCopyLink: copyInviteLink,
                    onSendReminder: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.activeSheet = .reminded
                        }
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
    }

    private var content: some View {
        VStack(spacing: DDSpacing.zero) {
            navigation

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heading
                        .frame(
                            minHeight: headingMinimumHeight,
                            alignment: .topLeading
                        )

                    if currentScreenState == .nicknameEntry {
                        nicknameField
                    }

                    TripSummaryCard()

                    ParticipantStatusCard(
                        style: participantCardStyle,
                        onWaitingParticipantTapped: showReminder
                    )

                    if currentScreenState == .allJoined {
                        nextStepCard
                    } else {
                        refreshStatus
                    }
                }
                .padding(.horizontal, DDSpacing.xLarge)
                .padding(.top, headingTopPadding)
                .padding(.bottom, DDSpacing.xLarge)
            }
            .scrollIndicators(.hidden)

            actions
        }
    }

    private var navigation: some View {
        ZStack {
            if currentScreenState == .nicknameEntry {
                VStack(spacing: 1) {
                    Text("도쿄 여행")
                        .ddTypography(.labelEmphasis14)
                    Text("11월 22일 ~ 25일")
                        .ddTypography(.caption12)
                        .foregroundStyle(DDColor.textSecondary)
                }
            }

            HStack(spacing: DDSpacing.zero) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .regular))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                if currentScreenState == .hostWaiting || currentScreenState == .allJoined {
                    Text(navigationTitle)
                        .ddTypography(.title24)
                }

                Spacer()
            }
        }
        .frame(height: 43)
        .padding(.horizontal, DDSpacing.large)
    }

    @ViewBuilder
    private var heading: some View {
        switch currentScreenState {
        case .hostWaiting:
            subtitle(
                first: "초대 링크를 친구에게 공유해 주세요.",
                second: "참여한 친구는 이곳에서 확인할 수 있어요."
            )

        case .nicknameEntry:
            VStack(alignment: .leading, spacing: DDSpacing.medium) {
                Text("닉네임을 적어주세따 ⚡")
                    .ddTypography(.title24)

                subtitle(
                    first: "헤더님이 같이 여행으로 초대했어요.",
                    second: "3박 4일 도쿄 여행"
                )
            }

        case .friendWaiting:
            VStack(alignment: .leading, spacing: DDSpacing.medium) {
                Text("다른 친구를 기다리고 이따 ⚡")
                    .ddTypography(.title24)

                Label("06:34:05", systemImage: "timer")
                    .ddTypography(.captionEmphasis12)
                    .foregroundStyle(DDColor.textSecondary)

                subtitle(
                    first: "초대 링크를 친구에게 공유해 주세요.",
                    second: "참여한 친구는 이곳에서 확인할 수 있어요."
                )
            }

        case .allJoined:
            subtitle(
                first: "나 포함 4명이 모두 합류했어요.",
                second: "각자 가고 싶은 장소를 선택해 보세요."
            )
        }
    }

    private func subtitle(first: String, second: String) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            Text(first)
            Text(second)
        }
        .ddTypography(.label14)
        .foregroundStyle(DDColor.textSecondary)
        .lineSpacing(2)
    }

    private var nicknameField: some View {
        TextField("닉네임 (예: 리도)", text: $nickname)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .ddTypography(.body16)
            .foregroundStyle(DDColor.textPrimary)
            .padding(.horizontal, DDSpacing.large)
            .frame(maxWidth: .infinity, minHeight: 39, alignment: .leading)
            .background(Color(red: 0.96, green: 0.96, blue: 0.96))
            .clipShape(.rect(cornerRadius: DDRadius.medium))
    }

    private var refreshStatus: some View {
        Button(action: refreshParticipants) {
            HStack(spacing: DDSpacing.small) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .regular))
                Text("참여 현황 새로고침")
                    .font(
                        currentScreenState == .friendWaiting
                            ? .custom("Pretendard-Regular", size: 13)
                            : .custom("Pretendard-Regular", size: 14)
                    )
            }
            .foregroundStyle(DDColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: currentScreenState == .nicknameEntry ? 32 : 26)
            .padding(.top, currentScreenState == .friendWaiting ? -9 : 0)
        }
        .buttonStyle(.plain)
    }

    private var nextStepCard: some View {
        VStack(alignment: .leading, spacing: DDSpacing.small) {
            Text("다음은, 가고 싶은 장소 고르기")
                .ddTypography(.labelEmphasis14)
            Text("각자의 선택을 모아 함께할 여행 그룹을 추천해드려요.")
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: DDRadius.medium))
    }

    private var actions: some View {
        Group {
            if currentScreenState == .allJoined {
                DDCTAButton(
                    title: "함께 장소 선택하기",
                    action: showSetupOverview
                )
            } else {
                HStack(spacing: DDSpacing.small) {
                    DDCTAButton(
                        title: "링크 공유",
                        style: .secondary,
                        action: showInviteSheet
                    )
                    DDCTAButton(
                        title: currentScreenState == .nicknameEntry ? "장소 선택" : "바로 시작",
                        isEnabled: canContinue,
                        action: showSetupOverview
                    )
                }
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, DDSpacing.small)
        .padding(.bottom, 11)
        .background(DDColor.surfaceDefault)
    }

    private var navigationTitle: String {
        currentScreenState == .allJoined ? "모두 함께할 준비가 돼따 ⚡" : "친구를 기다리고 이따 ⚡"
    }

    private var headingTopPadding: CGFloat {
        switch currentScreenState {
        case .hostWaiting, .allJoined: 6
        case .nicknameEntry, .friendWaiting: 29
        }
    }

    private var headingMinimumHeight: CGFloat {
        switch currentScreenState {
        case .hostWaiting, .nicknameEntry, .allJoined: 82
        case .friendWaiting: 115
        }
    }

    private var participantCardStyle: ParticipantStatusCard.Style {
        switch joinedCount {
        case ...2: .twoJoined
        case 3: .threeJoined
        default: .allJoined
        }
    }

    private var currentScreenState: ScreenState {
        if joinedCount == 4, screenState != .nicknameEntry {
            return .allJoined
        }
        return screenState
    }

    private var canContinue: Bool {
        guard currentScreenState == .nicknameEntry else { return true }
        return !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func showInviteSheet() {
        hasCopiedInviteLink = false
        withAnimation(.easeInOut(duration: 0.2)) {
            activeSheet = .invite
        }
    }

    private func showReminder(for participantName: String) {
        reminderTargetName = participantName
        hasCopiedInviteLink = false
        withAnimation(.easeInOut(duration: 0.2)) {
            activeSheet = .remind
        }
    }

    private func dismissSheet() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeSheet = nil
        }
    }

    private func copyInviteLink() {
        UIPasteboard.general.string = mockInviteLink
        hasCopiedInviteLink = true
    }

    private func refreshParticipants() {
        guard joinedCount < 4 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            joinedCount += 1
        }
    }

    private func showSetupOverview() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showsSetupOverview = true
        }
    }

    private static func initialJoinedCount(
        for screenState: ScreenState,
        presentedSheet: PresentedSheet?
    ) -> Int {
        if presentedSheet == .remind || presentedSheet == .reminded {
            return 4
        }

        switch screenState {
        case .hostWaiting, .nicknameEntry:
            return 2
        case .friendWaiting:
            return 3
        case .allJoined:
            return 4
        }
    }
}

private struct TripSummaryCard: View {
    var isCompact = false
    var height: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("3박 4일 도쿄 여행")
                .ddTypography(isCompact ? .bodyEmphasis16 : .heading18)
            Text("11월 22일–25일  ·  나 포함 총 4명")
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(.horizontal, isCompact ? DDSpacing.large : 18)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: DDRadius.medium))
    }
}

private struct ParticipantStatusCard: View {
    enum Style {
        case twoJoined
        case threeJoined
        case allJoined
    }

    private struct Participant {
        let name: String
        let character: DDMiniHeadAvatar.Character
        let showsAvatar: Bool
        let status: String
    }

    let style: Style
    let onWaitingParticipantTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DDSpacing.medium) {
            HStack {
                Text("함께하는 친구")
                    .ddTypography(.bodyEmphasis16)
                Spacer()
                Text("\(joinedCount)/4 참여 완료")
                    .ddTypography(.captionEmphasis12)
            }

            if style == .allJoined {
                statusDescription
            }

            HStack(spacing: DDSpacing.small) {
                ForEach(Array(participants.enumerated()), id: \.offset) { _, item in
                    participant(item)
                }
            }

            if style != .allJoined {
                statusDescription
            }
        }
        .padding(DDSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: DDRadius.medium))
    }

    private var statusDescription: some View {
        Text(
            style == .allJoined
                ? "모든 친구가 합류했어요. 이제 함께 장소를 골라보세요."
                : "빈 프로필을 누르면 참여 알림을 보내거나\n초대 링크를 다시 공유할 수 있어요."
        )
        .ddTypography(.caption12)
        .foregroundStyle(DDColor.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var participants: [Participant] {
        [
            Participant(name: "나", character: .tae, showsAvatar: true, status: "참여 완료"),
            Participant(name: "헤더", character: .header, showsAvatar: true, status: "참여 완료"),
            Participant(
                name: "주니",
                character: .juni,
                showsAvatar: style != .twoJoined,
                status: style == .twoJoined ? "참여 대기" : "참여 완료"
            ),
            Participant(
                name: "그레",
                character: .grae,
                showsAvatar: style == .allJoined,
                status: style == .allJoined ? "참여 완료" : "참여 대기"
            )
        ]
    }

    @ViewBuilder
    private func participant(_ participant: Participant) -> some View {
        if participant.showsAvatar {
            participantContent(participant)
                .accessibilityHint("참여 완료")
        } else {
            Button {
                onWaitingParticipantTapped(participant.name)
            } label: {
                participantContent(participant)
            }
            .buttonStyle(.plain)
            .accessibilityHint("참여 알림 메뉴 열기")
        }
    }

    private func participantContent(_ participant: Participant) -> some View {
        VStack(spacing: DDSpacing.xSmall) {
            if participant.showsAvatar {
                ZStack {
                    Circle()
                        .fill(avatarBackground(for: participant.character))

                    Image(participant.character.rawValue)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 44)
                }
                .frame(width: 56, height: 56)
            } else {
                ZStack {
                    Circle()
                        .stroke(
                            DDColor.borderDefault,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                    Image(systemName: "person")
                        .font(.system(size: 20, weight: .regular))
                }
                .frame(width: 56, height: 56)
            }

            Text(participant.name)
                .ddTypography(.labelEmphasis14)
            Text(participant.status)
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var joinedCount: Int {
        switch style {
        case .twoJoined: 2
        case .threeJoined: 3
        case .allJoined: 4
        }
    }

    private func avatarBackground(for character: DDMiniHeadAvatar.Character) -> Color {
        switch character {
        case .tae:
            Color(red: 217 / 255, green: 149 / 255, blue: 126 / 255)
        case .header:
            Color(red: 152 / 255, green: 156 / 255, blue: 209 / 255)
        case .juni:
            Color(red: 197 / 255, green: 143 / 255, blue: 167 / 255)
        case .grae:
            Color(red: 102 / 255, green: 181 / 255, blue: 173 / 255)
        }
    }
}

private struct TripInvitationBottomSheet: View {
    let style: TripInvitationStatusView.PresentedSheet
    let reminderTargetName: String
    let hasCopiedInviteLink: Bool
    let onDismiss: () -> Void
    let onCopyLink: () -> Void
    let onSendReminder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            Capsule()
                .fill(DDColor.borderDefault)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity, minHeight: 12, alignment: .top)
                .padding(.top, DDSpacing.medium)

            Text(title)
                .ddTypography(.title24)
                .frame(height: 30, alignment: .leading)
                .padding(.top, DDSpacing.large)
                .padding(.horizontal, DDSpacing.xLarge)

            subtitle
                .frame(height: 40, alignment: .topLeading)
                .padding(.top, 22)
                .padding(.horizontal, DDSpacing.xLarge)

            detailCard
                .padding(.top, 20)
                .padding(.horizontal, DDSpacing.xLarge)

            Spacer(minLength: DDSpacing.xLarge)

            actions
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, 45)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 482)
        .background(DDColor.surfaceDefault)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: DDSpacing.xLarge,
                topTrailingRadius: DDSpacing.xLarge
            )
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private var title: String {
        switch style {
        case .invite: "친구를 초대해요"
        case .remind: "참여를 한 번 더 알려줄까요?"
        case .reminded: "참여 알림을 보냈어요"
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            switch style {
            case .invite:
                Text("초대 링크로 친구와 여행을 함께 준비하세요.")
                Text("친구가 링크로 참여하면 현황에 표시돼요.")
            case .remind:
                Text("아직 합류하지 않은 친구에게 알림을 보내거나")
                Text("초대 링크를 다시 공유할 수 있어요.")
            case .reminded:
                Text("친구가 합류하면 참여 현황에 반영돼요.")
                Text("먼저 장소를 선택하며 기다려도 괜찮아요.")
            }
        }
        .ddTypography(.label14)
        .foregroundStyle(DDColor.textSecondary)
    }

    @ViewBuilder
    private var detailCard: some View {
        switch style {
        case .invite:
            TripSummaryCard(isCompact: true, height: 76)
        case .remind:
            reminderCard(
                subtitle: "참여 대기 · 아직 여행에 합류하지 않았어요"
            )
        case .reminded:
            reminderCard(subtitle: "방금 전 참여 알림 발송")
        }
    }

    private func reminderCard(subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.small) {
            Text(reminderTargetName)
                .ddTypography(.heading18)
            Text(subtitle)
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: DDRadius.medium))
    }

    @ViewBuilder
    private var actions: some View {
        switch style {
        case .invite:
            HStack(spacing: DDSpacing.small) {
                DDCTAButton(
                    title: "참여 현황",
                    style: .secondary,
                    action: onDismiss
                )
                DDCTAButton(
                    title: hasCopiedInviteLink ? "복사 완료" : "링크 복사",
                    action: onCopyLink
                )
            }
        case .remind:
            HStack(spacing: DDSpacing.small) {
                DDCTAButton(
                    title: hasCopiedInviteLink ? "복사 완료" : "링크 재공유",
                    style: .secondary,
                    action: onCopyLink
                )
                DDCTAButton(title: "알림 보내기", action: onSendReminder)
            }
        case .reminded:
            DDCTAButton(title: "확인", action: onDismiss)
        }
    }
}

#Preview("TripSetUpView_AddTravel_4") {
    TripInvitationStatusView(screenState: .hostWaiting)
}

#Preview("TripSetUpView_AddTravel_5") {
    TripInvitationStatusView(screenState: .hostWaiting, presentedSheet: .invite)
}

#Preview("TripSetUpView_FriendAddTravel_3_AllJoined") {
    TripInvitationStatusView(screenState: .allJoined)
}

#Preview("TripSetUpView_AddTravel_5_Remind") {
    TripInvitationStatusView(screenState: .hostWaiting, presentedSheet: .remind)
}

#Preview("TripSetUpView_AddTravel_6_Reminded") {
    TripInvitationStatusView(screenState: .hostWaiting, presentedSheet: .reminded)
}

#Preview("TripSetUpView_FriendAddTravel_1") {
    TripInvitationStatusView(screenState: .nicknameEntry)
}

#Preview("TripSetUpView_FriendAddTravel_2") {
    TripInvitationStatusView(screenState: .friendWaiting)
}
