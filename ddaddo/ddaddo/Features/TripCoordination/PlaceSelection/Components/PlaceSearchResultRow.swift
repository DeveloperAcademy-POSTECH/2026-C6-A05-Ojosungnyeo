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
        ZStack(alignment: .topLeading) {
            ZStack {
                Circle()
                    .fill(DDColor.actionSecondary)

                Image(systemName: "mappin")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DDColor.textSecondary)
            }
            .frame(width: 40, height: 40)
            .padding(.leading, DDSpacing.xLarge)
            .padding(.top, DDSpacing.small)

            VStack(alignment: .leading, spacing: 0) {
                Text(result.name)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 177, height: 20, alignment: .topLeading)

                Text(result.address)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 200, alignment: .topLeading)

                Divider()
                    .overlay(DDColor.borderSubtle)
                    .frame(width: 290)
                    .padding(.top, 12)
            }
            .padding(.leading, 87)
        }
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(.rect)
    }
}
