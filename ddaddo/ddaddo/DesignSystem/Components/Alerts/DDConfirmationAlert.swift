//
//  DDConfirmationAlert.swift
//  ddaddo
//

import SwiftUI

struct DDConfirmationAlert: View {
    let title: String
    let message: String
    let cancelTitle: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private let dividerColor = Color(red: 72 / 255, green: 72 / 255, blue: 72 / 255)
    private let secondaryTextColor = Color(red: 204 / 255, green: 204 / 255, blue: 204 / 255)

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

            HStack(spacing: DDSpacing.zero) {
                actionButton(title: cancelTitle, color: secondaryTextColor, action: onCancel)

                dividerColor.frame(width: 0.5)

                actionButton(title: confirmTitle, color: DDColor.actionPrimary, action: onConfirm)
            }
            .frame(height: 48)
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
