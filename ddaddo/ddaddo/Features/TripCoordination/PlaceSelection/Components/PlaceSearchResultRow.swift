//
//  PlaceSearchResultRow.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct PlaceSearchResultRow: View {
    let result: PlaceSearchResult

    var body: some View {
        HStack(spacing: DDSpacing.xLarge) {
            ZStack {
                Circle()
                    .fill(DDColor.actionSecondary)

                Image(systemName: "mappin")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DDColor.textSecondary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 0) {
                Text(result.name)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                Text(result.address)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(2)

                Divider()
                    .overlay(DDColor.borderSubtle)
                    .padding(.top, DDSpacing.small)
            }
        }
        .padding(.leading, DDSpacing.xLarge)
        .padding(.trailing, DDSpacing.xLarge)
        .frame(minHeight: 77)
        .contentShape(.rect)
    }
}
