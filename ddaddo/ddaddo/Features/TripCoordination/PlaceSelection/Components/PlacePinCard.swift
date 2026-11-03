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
        HStack(spacing: 10) {
            thumbnail

            VStack(alignment: .leading, spacing: DDSpacing.zero) {
                Text(place.name)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                Text(place.category)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.surfaceSelected)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 72, alignment: .leading)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = place.photoData.first, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipped()
                .clipShape(.rect(cornerRadius: 12))
        } else if !place.thumbnailName.isEmpty,
                  let image = UIImage(named: place.thumbnailName) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipped()
                .clipShape(.rect(cornerRadius: 12))
        } else {
            ZStack {
                DDColor.surfaceControl

                Image("DDEarth")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 39, height: 36)
            }
            .frame(width: 44, height: 44)
            .clipShape(.rect(cornerRadius: 12))
        }
    }
}
