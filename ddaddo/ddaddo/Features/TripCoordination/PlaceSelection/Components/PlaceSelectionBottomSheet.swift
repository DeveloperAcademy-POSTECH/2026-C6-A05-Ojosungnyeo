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
    let bottomSafeAreaInset: CGFloat
    let memberTapped: (TripMember) -> Void
    let searchButtonTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 19)

            avatarGroup
                .padding(.top, DDSpacing.xLarge)

            if isExpanded {
                Text("아직 추가한 장소가 없따...")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.top, DDSpacing.large)

                Text("\(destinationName)에서 꼭 가고 싶은 장소를\n\(maximumPlaceCount)개까지 추가해 보세요.")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineSpacing(0)
                    .padding(.top, DDSpacing.large)

                Spacer(minLength: DDSpacing.large)

                DDCTAButton(title: "장소 검색하기", action: searchButtonTapped)
                    .padding(.bottom, max(DDSpacing.xLarge, bottomSafeAreaInset + 11))
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: (isExpanded ? 288 : 501) + bottomSafeAreaInset)
        .background(DDColor.surfaceDefault)
        .clipShape(
            .rect(
                topLeadingRadius: 40,
                topTrailingRadius: 40
            )
        )
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

    private var avatarGroup: some View {
        HStack(spacing: DDSpacing.small) {
            ForEach(participants) { participant in
                if participant.hasJoined {
                    Button {
                        memberTapped(participant.member)
                    } label: {
                        PlaceSelectionParticipantAvatar(
                            participant: participant,
                            isSelected: selectedMember == participant.member
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
                    .overlay {
                        if !isSelected {
                            Circle()
                                .fill(
                                    Color(
                                        red: 74 / 255,
                                        green: 74 / 255,
                                        blue: 74 / 255
                                    )
                                    .opacity(0.6)
                                )
                        }
                    }

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
                            DDColor.textSecondary,
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )

                    Image(systemName: "person")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DDColor.textPrimary)
                }
                .accessibilityLabel("\(participant.name) 참여 대기")
            }
        }
        .frame(width: 40, height: 40)
    }
}
