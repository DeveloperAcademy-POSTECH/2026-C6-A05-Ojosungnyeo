//
//  PlacePinCard.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct PlacePinCard: View {
    let place: PinnedPlace
    var showsDragHandle = false
    var dragCoordinateSpaceName = "memberPlacesDrag"
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?

    var body: some View {
        HStack(spacing: DDSpacing.medium) {
            thumbnail

            VStack(alignment: .leading, spacing: DDSpacing.zero) {
                Text(place.name)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)
                    .frame(height: 24, alignment: .topLeading)

                Text(place.category)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.surfaceSelected)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .frame(height: 20, alignment: .topLeading)
            }
            .frame(height: 44, alignment: .topLeading)

            Spacer(minLength: 0)

            if showsDragHandle {
                dragHandle
            }
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

    private var dragHandle: some View {
        HStack(spacing: 3.39) {
            verticalEllipsis
            verticalEllipsis
        }
        .frame(width: 12, height: 22)
        .frame(width: 32, height: 44, alignment: .trailing)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(
                minimumDistance: 0,
                coordinateSpace: .named(dragCoordinateSpaceName)
            )
                .onChanged { drag in
                    onDragChanged?(drag.location)
                }
                .onEnded { drag in
                    onDragEnded?(drag.location)
                }
        )
        .accessibilityLabel("장소 순서 변경")
    }

    private var verticalEllipsis: some View {
        Image(systemName: "ellipsis")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 4)
            .rotationEffect(.degrees(90))
            .frame(width: 4, height: 18)
            .foregroundStyle(DDColor.textSecondary)
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
