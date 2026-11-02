//
//  PlaceSelectionBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct PlaceSelectionBottomSheet: View {
    let isExpanded: Bool
    let selectedMember: TripMember
    let participants: [PlaceSelectionFeature.Participant]
    let destinationName: String
    let maximumPlaceCount: Int
    let memberTapped: (TripMember) -> Void
    let searchButtonTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 80, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, DDSpacing.large)

            avatarGroup
                .padding(.top, DDSpacing.large)

            if isExpanded {
                Text("아직 추가한 장소가 없따...")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.top, DDSpacing.large)

                Text("\(destinationName)에서 꼭 가고 싶은 장소를\n\(maximumPlaceCount)개까지 추가해 보세요.")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineSpacing(0)
                    .padding(.top, DDSpacing.medium)

                Spacer(minLength: DDSpacing.large)

                DDCTAButton(title: "장소 검색하기", action: searchButtonTapped)
                    .padding(.bottom, 45)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 322 : 535)
        .background(DDColor.surfaceDefault)
        .clipShape(
            .rect(
                topLeadingRadius: 40,
                topTrailingRadius: 40
            )
        )
    }

    private var avatarGroup: some View {
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

struct PlaceSelectionParticipantAvatar: View {
    let participant: PlaceSelectionFeature.Participant
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if participant.hasJoined {
                DDMiniHeadAvatar(character: participant.member.avatar, size: 40)
                    .saturation(isSelected ? 1 : 0.25)
                    .opacity(isSelected ? 1 : 0.5)

                if participant.isConfirmed {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.black)
                        }
                        .offset(x: 2, y: -2)
                }
            } else {
                ZStack {
                    Circle()
                        .stroke(
                            DDColor.borderDefault,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )

                    Image(systemName: "person")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(DDColor.iconDefault)
                }
                .accessibilityLabel("\(participant.name) 참여 대기")
            }
        }
        .frame(width: 40, height: 40)
    }
}
