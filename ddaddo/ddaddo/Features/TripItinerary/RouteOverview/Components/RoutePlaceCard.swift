//
//  RoutePlaceCard.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import SwiftUI

struct RoutePlaceCard: View {
    let place: RoutePlace
    let addressCopyButtonTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: DDSpacing.small) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(place.name)
                        .ddTypography(.bodyEmphasis16)
                        .foregroundStyle(DDColor.textPrimary)

                    Text(place.description)
                        .ddTypography(.label14)
                        .foregroundStyle(DDColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                memberAvatars
            }

            Spacer(minLength: DDSpacing.small)

            Button(action: addressCopyButtonTapped) {
                HStack(alignment: .bottom, spacing: DDSpacing.xSmall) {
                    Text(place.address)
                        .ddTypography(.label14)
                        .foregroundStyle(DDColor.textPrimary)
                        .underline()
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Image(systemName: "document.on.document")
                        .font(.system(size: 14))
                        .foregroundStyle(DDColor.textPrimary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 126, maxHeight: 126, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private var memberAvatars: some View {
        HStack(spacing: -8) {
            ForEach(place.members, id: \.self) { member in
                DDMiniHeadAvatar(character: member.avatarCharacter, size: 40)
            }
        }
    }
}

private extension TripMember {
    var avatarCharacter: DDMiniHeadAvatar.Character {
        switch self {
        case .tae: .tae
        case .header: .header
        case .grae: .grae
        case .juni: .juni
        }
    }
}
