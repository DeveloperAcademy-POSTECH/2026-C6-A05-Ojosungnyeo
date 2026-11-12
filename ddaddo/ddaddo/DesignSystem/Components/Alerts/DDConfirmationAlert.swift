//
//  DDConfirmationAlert.swift
//  ddaddo
//

import SwiftUI

struct DDConfirmationAlert: View {
    @Environment(\.displayScale) private var displayScale

    let title: String
    let message: String
    let cancelTitle: String?
    let confirmTitle: String
    var cancelColor: Color?
    var confirmColor: Color = DDColor.actionPrimary
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void

    init(
        title: String,
        message: String,
        cancelTitle: String? = nil,
        confirmTitle: String,
        cancelColor: Color? = nil,
        confirmColor: Color = DDColor.actionPrimary,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.cancelColor = cancelColor
        self.confirmColor = confirmColor
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: DDSpacing.zero) {
            VStack(spacing: DDSpacing.small) {
                Text(title)
                    .font(.custom("Pretendard-SemiBold", size: 17, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 24)

                Text(message)
                    .font(.custom("Pretendard-Regular", size: 13, relativeTo: .footnote))
                    .foregroundStyle(DDColor.alertSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, DDSpacing.xLarge)

            separator.frame(height: separatorThickness)

            if let cancelTitle, let onCancel {
                HStack(spacing: DDSpacing.zero) {
                    actionButton(
                        title: cancelTitle,
                        color: cancelColor ?? DDColor.alertSecondary,
                        action: onCancel
                    )

                    separator.frame(width: separatorThickness)

                    actionButton(title: confirmTitle, color: confirmColor, action: onConfirm)
                }
                .frame(height: 48)
            } else {
                actionButton(title: confirmTitle, color: confirmColor, action: onConfirm)
                    .frame(height: 48)
            }
        }
        .frame(width: 286)
        .background(DDColor.alertSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func actionButton(
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var separator: Color {
        .white.opacity(0.5)
    }

    private var separatorThickness: CGFloat {
        1 / displayScale
    }
}

struct DDAlertOverlay: View {
    let title: String
    let message: String
    let cancelTitle: String?
    let confirmTitle: String
    var cancelColor: Color?
    var confirmColor: Color = DDColor.actionPrimary
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void

    init(
        title: String,
        message: String,
        cancelTitle: String? = nil,
        confirmTitle: String,
        cancelColor: Color? = nil,
        confirmColor: Color = DDColor.actionPrimary,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.cancelColor = cancelColor
        self.confirmColor = confirmColor
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)

            DDConfirmationAlert(
                title: title,
                message: message,
                cancelTitle: cancelTitle,
                confirmTitle: confirmTitle,
                cancelColor: cancelColor,
                confirmColor: confirmColor,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
    }
}

private struct DDAlertPreviewCase: Identifiable {
    let name: String
    let title: String
    let message: String
    var cancelTitle: String? = nil
    var confirmTitle = "확인"
    var isDestructive = false

    var id: String { name }

    static let all: [DDAlertPreviewCase] = [
        .init(
            name: "친구 초대",
            title: "친구를 초대할까요?",
            message: "여행 계획을 위한 모든 준비가 끝났어요.\n친구를 초대하러 가시겠어요?",
            cancelTitle: "아니요",
            confirmTitle: "네"
        ),
        .init(
            name: "먼저 여행 준비",
            title: "먼저 여행을 준비할까요?",
            message: "지도에서 가고 싶은 장소를 선택해 주세요.",
            cancelTitle: "아니요",
            confirmTitle: "네"
        ),
        .init(
            name: "이동 수단 변경",
            title: "이동 수단을 변경할까요?",
            message: "변경하면 다시 분석해 추천 그룹이 달라져요.\n그래도 변경하시겠어요?",
            cancelTitle: "아니요",
            confirmTitle: "네"
        ),
        .init(
            name: "그룹 합류",
            title: "합류할까요?",
            message: "합류하면 지금까지 담은 일정이 초기화돼요.\n그래도 합류하시겠어요?",
            cancelTitle: "아니요",
            confirmTitle: "네"
        ),
        .init(
            name: "로그아웃",
            title: "로그아웃할까요?",
            message: "로그아웃하면 로그인 화면으로 이동해요.",
            cancelTitle: "취소",
            confirmTitle: "로그아웃"
        ),
        .init(
            name: "일정 삭제",
            title: "일정을 삭제할까요?",
            message: "삭제한 일정은 여행 일정에서 사라져요.",
            cancelTitle: "아니요",
            confirmTitle: "네",
            isDestructive: true
        ),
        .init(
            name: "장소 삭제",
            title: "장소를 삭제할까요?",
            message: "삭제한 장소는 목록에서 사라져요.",
            cancelTitle: "아니요",
            confirmTitle: "네",
            isDestructive: true
        ),
        .init(
            name: "여행 삭제",
            title: "여행을 삭제할까요?",
            message: "삭제한 여행은 예정된 여행 목록에서 사라져요.",
            cancelTitle: "아니요",
            confirmTitle: "네",
            isDestructive: true
        ),
        .init(
            name: "회원 탈퇴",
            title: "회원 탈퇴할까요?",
            message: "탈퇴하면 계정을 다시 복구하거나\n로그인할 수 없어요.",
            cancelTitle: "돌아가기",
            confirmTitle: "탈퇴하기",
            isDestructive: true
        ),
        .init(
            name: "초대 인원 마감",
            title: "초대 인원이 모두 찼어요",
            message: "이 여행은 정원이 가득 차 참여할 수 없어요.\n초대한 친구에게 확인해 주세요."
        ),
        .init(
            name: "장소 선택 완료",
            title: "모두 장소 선택을 마쳤어요",
            message: "4명 모두 장소핀을 확정했어요.\n확정된 장소로 추천 그룹을 만들어 드릴게요."
        ),
        .init(
            name: "장소 선택 시간 종료",
            title: "72시간이 지났어요",
            message: "지금까지 확정된 장소핀으로\n추천 그룹을 만들어 드릴게요."
        ),
        .init(
            name: "일정 저장 실패",
            title: "일정을 저장할 수 없어요",
            message: "일정을 저장하지 못했어요.\n잠시 후 다시 시도해 주세요."
        ),
        .init(
            name: "여행 생성 실패",
            title: "여행을 만들지 못했어요",
            message: "잠시 후 다시 시도해 주세요."
        ),
        .init(
            name: "여행 참여 실패",
            title: "여행에 참여할 수 없어요",
            message: "초대 코드가 유효하지 않아요."
        ),
        .init(
            name: "여행 삭제 실패",
            title: "여행을 삭제하지 못했어요",
            message: "네트워크 연결을 확인해 주세요."
        ),
        .init(
            name: "요청 실패",
            title: "요청을 완료하지 못했어요",
            message: "잠시 후 다시 시도해 주세요."
        ),
        .init(
            name: "장소 저장 실패",
            title: "장소를 서버에 저장하지 못했어요",
            message: "네트워크 연결을 확인해 주세요."
        ),
        .init(
            name: "회원 탈퇴 실패",
            title: "탈퇴할 수 없어요",
            message: "보안을 위해 다시 로그인한 뒤 시도해 주세요."
        )
    ]
}

private struct DDAlertPreviewGallery: View {
    let cases: [DDAlertPreviewCase]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DDSpacing.xLarge) {
                ForEach(cases) { item in
                    VStack(alignment: .leading, spacing: DDSpacing.small) {
                        Text(item.name)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.textSecondary)

                        alert(item)
                    }
                }
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.vertical, DDSpacing.xLarge)
        }
        .background(DDColor.surfaceDefault)
    }

    @ViewBuilder
    private func alert(_ item: DDAlertPreviewCase) -> some View {
        if let cancelTitle = item.cancelTitle {
            DDConfirmationAlert(
                title: item.title,
                message: item.message,
                cancelTitle: cancelTitle,
                confirmTitle: item.confirmTitle,
                confirmColor: item.isDestructive
                    ? DDColor.alertDestructive
                    : DDColor.actionPrimary,
                onCancel: {},
                onConfirm: {}
            )
        } else {
            DDConfirmationAlert(
                title: item.title,
                message: item.message,
                confirmTitle: item.confirmTitle,
                onConfirm: {}
            )
        }
    }
}

#Preview("전체 알림") {
    DDAlertPreviewGallery(cases: DDAlertPreviewCase.all)
        .preferredColorScheme(.dark)
}
