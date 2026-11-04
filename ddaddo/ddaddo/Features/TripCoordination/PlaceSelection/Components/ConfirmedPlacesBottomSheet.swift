//
//  ConfirmedPlacesBottomSheet.swift
//  ddaddo
//

import SwiftUI

struct ConfirmedPlacesBottomSheet: View {
    let participants: [PlaceSelectionFeature.Participant]
    let places: [PinnedPlace]
    var bottomSafeAreaInset: CGFloat = 34
    let memberTapped: (TripMember) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 19)

            HStack(spacing: DDSpacing.small) {
                ForEach(participants) { participant in
                    if participant.hasJoined {
                        Button {
                            memberTapped(participant.member)
                        } label: {
                            PlaceSelectionParticipantAvatar(
                                participant: participant,
                                isSelected: participant.isConfirmed
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        PlaceSelectionParticipantAvatar(
                            participant: participant,
                            isSelected: false
                        )
                    }
                }

                Spacer(minLength: DDSpacing.small)

                Text("확정완료")
                    .font(.custom("Pretendard-Bold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DDColor.textOnPrimary)
                    .padding(.horizontal, DDSpacing.medium)
                    .frame(height: 28)
                    .background(DDColor.surfaceSelected)
                    .clipShape(.capsule)
            }
            .padding(.top, DDSpacing.xLarge)

            Text("확정된 장소")
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
        .frame(height: 379 + bottomSafeAreaInset, alignment: .top)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40
            )
            .stroke(DDColor.borderDefault, lineWidth: 1)
            .allowsHitTesting(false)
        }
    }
}
