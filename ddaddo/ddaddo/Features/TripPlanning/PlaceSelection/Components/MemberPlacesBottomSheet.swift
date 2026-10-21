//
//  MemberPlacesBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct MemberPlacesBottomSheet: View {
    let isExpanded: Bool
    let selectedMember: TripMember
    let places: [PinnedPlace]
    let memberTapped: (TripMember) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 19)

            memberSelector
                .padding(.top, DDSpacing.xLarge)

            if isExpanded {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: DDSpacing.medium) {
                        ForEach(places) { place in
                            PlacePinCard(place: place)
                        }
                    }
                    .padding(.bottom, DDSpacing.xLarge)
                }
                .padding(.top, DDSpacing.medium)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 535 : 156)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
    }

    private var memberSelector: some View {
        HStack(spacing: DDSpacing.xSmall) {
            ForEach(TripMember.allCases) { member in
                Button {
                    memberTapped(member)
                } label: {
                    DDMiniHeadAvatar(character: member.character, size: 34)
                        .padding(3)
                        .background(
                            selectedMember == member
                                ? DDColor.actionPrimary
                                : DDColor.surfaceControl
                        )
                        .clipShape(.circle)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private extension TripMember {
    var character: DDMiniHeadAvatar.Character {
        switch self {
        case .tae: .tae
        case .header: .header
        case .grae: .grae
        case .juni: .juni
        }
    }
}
