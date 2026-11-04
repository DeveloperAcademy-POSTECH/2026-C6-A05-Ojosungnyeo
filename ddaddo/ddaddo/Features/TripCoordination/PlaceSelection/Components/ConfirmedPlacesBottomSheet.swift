//
//  ConfirmedPlacesBottomSheet.swift
//  ddaddo
//

import SwiftUI

struct ConfirmedPlacesBottomSheet: View {
    let participants: [PlaceSelectionFeature.Participant]
    let places: [PinnedPlace]

    var body: some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 19)

            HStack(spacing: DDSpacing.small) {
                ForEach(participants.filter(\.hasJoined)) { participant in
                    PlaceSelectionParticipantAvatar(
                        participant: participant,
                        isSelected: participant.isConfirmed
                    )
                }

                Spacer(minLength: DDSpacing.small)

                Text("확정완료")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textOnPrimary)
                    .padding(.horizontal, DDSpacing.medium)
                    .frame(height: 28)
                    .background(DDColor.surfaceSelected)
                    .clipShape(.capsule)
            }
            .padding(.top, DDSpacing.xLarge)

            Text("전체 여행 일정")
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.top, 14)

            if places.isEmpty {
                Text("확정된 장소가 없어요")
                    .ddTypography(.body16)
                    .foregroundStyle(DDColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 92)
            } else {
                ScrollView {
                    LazyVStack(spacing: DDSpacing.medium) {
                        ForEach(places) { place in
                            PlacePinCard(place: place)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 18)
                .padding(.horizontal, -2)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: 535, alignment: .top)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
    }
}
