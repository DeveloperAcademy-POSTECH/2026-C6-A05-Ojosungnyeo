//
//  DDConfirmedScheduleCard.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct DDConfirmedScheduleCard: View {
    let time: String
    let title: String
    let detail: String
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(time)
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)

            Text(title)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)

            Text(detail)
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.textTertiary, lineWidth: 1)
        }
    }
}
