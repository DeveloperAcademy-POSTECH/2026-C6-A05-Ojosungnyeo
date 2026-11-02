//
//  DDConfirmationAlert.swift
//  ddaddo
//

import SwiftUI

struct DDConfirmationAlert: View {
    let title: String
    let message: String
    let cancelTitle: String?
    let confirmTitle: String
    var confirmColor: Color = DDColor.actionPrimary
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void

    private let dividerColor = Color(red: 72 / 255, green: 72 / 255, blue: 72 / 255)
    private let secondaryTextColor = Color(red: 204 / 255, green: 204 / 255, blue: 204 / 255)

    init(
        title: String,
        message: String,
        cancelTitle: String? = nil,
        confirmTitle: String,
        confirmColor: Color = DDColor.actionPrimary,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.confirmColor = confirmColor
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: DDSpacing.zero) {
            VStack(spacing: 10) {
                Text(title)
                    .font(.custom("Pretendard-SemiBold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DDColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.custom("Pretendard-Regular", size: 13, relativeTo: .footnote))
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, DDSpacing.xLarge)

            dividerColor.frame(height: 0.5)

            if let cancelTitle, let onCancel {
                HStack(spacing: DDSpacing.zero) {
                    actionButton(title: cancelTitle, color: secondaryTextColor, action: onCancel)

                    dividerColor.frame(width: 0.5)

                    actionButton(title: confirmTitle, color: confirmColor, action: onConfirm)
                }
                .frame(height: 48)
            } else {
                actionButton(title: confirmTitle, color: confirmColor, action: onConfirm)
                    .frame(height: 48)
            }
        }
        .frame(width: 286)
        .background(Color(red: 37 / 255, green: 37 / 255, blue: 37 / 255))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func actionButton(
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Pretendard-SemiBold", size: 17, relativeTo: .headline))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DDConfirmationAlert(
        title: "친구를 초대할까요?",
        message: "여행 계획을 위한 모든 준비가 끝났어요.\n친구를 초대하러 가시겠어요?",
        cancelTitle: "아니요",
        confirmTitle: "네",
        onCancel: {},
        onConfirm: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("단일 확인") {
    DDConfirmationAlert(
        title: "모두 장소 선택을 마쳤어요",
        message: "4명 모두 장소핀을 확정했어요.\n이제 함께 갈 장소를 묶어볼까요?\n다음 그룹핑 단계로 넘어가세요.",
        confirmTitle: "확인",
        onConfirm: {}
    )
    .preferredColorScheme(.dark)
}
