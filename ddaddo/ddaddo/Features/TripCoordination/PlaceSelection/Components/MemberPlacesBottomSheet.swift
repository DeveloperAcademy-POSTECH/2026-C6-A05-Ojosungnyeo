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
    let canDeletePlaces: Bool
    let canConfirm: Bool
    var bottomContentInset: CGFloat = DDSpacing.xLarge
    let memberTapped: (TripMember) -> Void
    let placeTapped: (PinnedPlace) -> Void
    let deletePlace: (PinnedPlace) -> Void
    let confirmButtonTapped: () -> Void

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
                if places.isEmpty {
                    Text("아직 핀 찍힌 장소가 없어요")
                        .ddTypography(.body16)
                        .foregroundStyle(DDColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 139)

                    Spacer(minLength: bottomContentInset)
                } else {
                    placeList
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: 535)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
    }

    private var memberSelector: some View {
        HStack(spacing: DDSpacing.small) {
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

            Spacer(minLength: DDSpacing.small)

            Button("확정하기", action: confirmButtonTapped)
                .ddTypography(.label14)
                .foregroundStyle(canConfirm ? DDColor.textPrimary : DDColor.textTertiary)
                .padding(.horizontal, DDSpacing.medium)
                .frame(height: 28)
                .background(DDColor.surfaceControl)
                .clipShape(.capsule)
                .disabled(!canConfirm)
        }
    }

    private var placeList: some View {
        ScrollView {
            LazyVStack(spacing: DDSpacing.medium) {
                ForEach(places) { place in
                    SwipeToDeletePlaceRow(
                        place: place,
                        canDelete: canDeletePlaces,
                        placeTapped: { placeTapped(place) },
                        deleteTapped: { deletePlace(place) }
                    )
                }

                Color.clear
                    .frame(height: bottomContentInset)
            }
            .padding(.top, 25)
        }
        .scrollIndicators(.hidden)
    }
}

private struct SwipeToDeletePlaceRow: View {
    private let actionWidth: CGFloat = 72
    private let revealOffset: CGFloat = 84

    let place: PinnedPlace
    let canDelete: Bool
    let placeTapped: () -> Void
    let deleteTapped: () -> Void

    @State private var horizontalOffset: CGFloat = 0
    @State private var settledOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDelete {
                deleteButton
            }

            PlacePinCard(place: place)
                .contentShape(.rect)
                .offset(x: horizontalOffset)
                .simultaneousGesture(swipeGesture)
                .onTapGesture {
                    if settledOffset == 0 {
                        placeTapped()
                    } else {
                        closeActions()
                    }
                }
        }
        .frame(height: 72)
        .clipped()
    }

    private var deleteButton: some View {
        Button {
            closeActions()
            deleteTapped()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DDColor.surfaceSelected)
                .frame(width: actionWidth, height: 72)
                .background(DDColor.actionSecondary)
                .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard canDelete,
                      abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                horizontalOffset = min(
                    0,
                    max(-revealOffset, settledOffset + value.translation.width)
                )
            }
            .onEnded { value in
                guard canDelete else {
                    return
                }

                let predictedOffset = settledOffset + value.predictedEndTranslation.width
                let shouldReveal = horizontalOffset < -(revealOffset / 3)
                    || predictedOffset < -(revealOffset / 2)
                let destination = shouldReveal ? -revealOffset : 0

                withAnimation(.snappy(duration: 0.25)) {
                    horizontalOffset = destination
                    settledOffset = destination
                }
            }
    }

    private func closeActions() {
        withAnimation(.snappy(duration: 0.2)) {
            horizontalOffset = 0
            settledOffset = 0
        }
    }
}
