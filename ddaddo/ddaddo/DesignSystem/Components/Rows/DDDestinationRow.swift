//
//  DDDestinationRow.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct DDDestinationRow<Artwork: View>: View {
    let title: String
    let isSelected: Bool
    @ViewBuilder let artwork: () -> Artwork

    var body: some View {
        HStack(spacing: DDSpacing.large) {
            artwork()
                .frame(width: 60, height: 60)
                .background(DDColor.surfaceControl)
                .clipShape(.rect(cornerRadius: DDRadius.medium))

            Text(title)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textSecondary)

            Spacer(minLength: DDSpacing.small)

            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 22))
                .foregroundStyle(
                    isSelected ? DDColor.actionPrimary : DDColor.borderDefault
                )
        }
        .frame(minHeight: 60)
        .contentShape(.rect)
    }
}
