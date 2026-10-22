//
//  TimeTableGroupCard.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import SwiftUI

struct TimeTableGroupCard: View {
    let group: TimeTableGroup
    let addButtonTapped: () -> Void

    var body: some View {
        Button(action: addButtonTapped) {
            VStack(alignment: .leading, spacing: 0) {
                Text(group.city)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                Text(group.memberNames)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(1)

                Text(group.placeName)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 6)
            .frame(width: 134, height: 72, alignment: .leading)
            .background(DDColor.actionPrimary)
            .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
