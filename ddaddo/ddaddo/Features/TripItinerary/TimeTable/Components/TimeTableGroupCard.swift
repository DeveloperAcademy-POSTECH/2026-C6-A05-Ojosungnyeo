//
//  TimeTableGroupCard.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import SwiftUI

struct TimeTableGroupCard: View {
    let group: TimeTableGroup
    let participantSummary: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(group.name)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textOnPrimary)
                .lineLimit(1)

            Text(participantSummary)
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 9)
        .frame(width: 100, height: 72, alignment: .leading)
        .background(DDColor.textPrimary)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(alignment: .topTrailing) {
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DDColor.textTertiary)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.name) 그룹 일정 배치")
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}
