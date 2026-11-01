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
    let participants: [PlaceSelectionFeature.Participant]
    let places: [PinnedPlace]
    var bottomContentInset: CGFloat = DDSpacing.xLarge
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
                    .padding(.bottom, bottomContentInset)
                }
                .padding(.top, DDSpacing.medium)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 395 : 156)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
    }

    private var memberSelector: some View {
        HStack(spacing: DDSpacing.xSmall) {
            ForEach(participants) { participant in
                Button {
                    memberTapped(participant.member)
                } label: {
                    PlaceSelectionParticipantAvatar(
                        participant: participant,
                        isSelected: selectedMember == participant.member
                    )
                }
                .buttonStyle(.plain)
                .disabled(!participant.hasJoined)
            }
        }
    }
}
