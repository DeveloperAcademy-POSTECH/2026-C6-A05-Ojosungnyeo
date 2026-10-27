//
//  SelectedPlaceBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct SelectedPlaceBottomSheet: View {
    let place: PlaceDetails
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 19)

            HStack(alignment: .top, spacing: DDSpacing.small) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .ddTypography(.heading18)
                        .foregroundStyle(DDColor.textPrimary)
                        .lineLimit(1)

                    ratingView
                }

                Spacer(minLength: DDSpacing.small)

                Button("추가하기") {}
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(DDColor.surfaceControl)
                    .clipShape(.capsule)
            }
            .padding(.top, 36)

            Text(place.category)
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.top, DDSpacing.small)

            HStack(alignment: .bottom, spacing: DDSpacing.xSmall) {
                Text(place.address)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textTertiary)
                    .underline()
                    .lineLimit(2)

                Image(systemName: "document.on.document")
                    .font(.system(size: 14))
                    .foregroundStyle(DDColor.textTertiary)
            }
            .padding(.top, 2)

            photoStrip
                .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: 395)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(DDColor.actionPrimary)
            }
        }
    }

    private var ratingView: some View {
        HStack(spacing: DDSpacing.xSmall) {
            Text(place.rating > 0 ? place.rating.formatted(.number.precision(.fractionLength(1))) : "-")

            HStack(spacing: 1) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: Double(value) <= place.rating ? "star.fill" : "star")
                }
            }

            Text("(\(place.ratingCount))")
        }
        .font(.system(size: 14))
        .foregroundStyle(DDColor.textSecondary)
        .frame(height: 20)
    }

    @ViewBuilder
    private var photoStrip: some View {
        if place.photoData.isEmpty {
            RoundedRectangle(cornerRadius: 20)
                .fill(DDColor.surfaceElevated)
                .frame(width: 205, height: 154)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DDSpacing.medium) {
                    ForEach(Array(place.photoData.enumerated()), id: \.offset) { _, data in
                        if let image = UIImage(data: data) {
                            Rectangle()
                                .foregroundStyle(.clear)
                                .frame(width: 205, height: 154)
                                .background {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 205, height: 154)
                                        .clipped()
                                }
                                .clipShape(.rect(cornerRadius: 20))
                        }
                    }
                }
            }
            .frame(height: 154)
        }
    }
}
