//
//  TimeTableGroupCard.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import SwiftUI

struct TimeTableGroupCard: View {
    let group: TimeTableGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(group.name)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textOnPrimary)
                .lineLimit(1)

            Text(group.participantSummary)
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
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(DDColor.textTertiary)
                .padding(.top, 8)
                .padding(.trailing, 9)
                .accessibilityHidden(true)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
