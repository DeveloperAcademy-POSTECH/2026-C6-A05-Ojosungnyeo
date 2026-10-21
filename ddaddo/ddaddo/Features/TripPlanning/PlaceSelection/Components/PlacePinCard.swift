//
//  PlacePinCard.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct PlacePinCard: View {
    let place: PinnedPlace

    var body: some View {
        HStack(spacing: DDSpacing.medium) {
            Image(place.thumbnailName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 0) {
                Text(place.name)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                Text(place.description)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DDSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 83, alignment: .leading)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }
}
