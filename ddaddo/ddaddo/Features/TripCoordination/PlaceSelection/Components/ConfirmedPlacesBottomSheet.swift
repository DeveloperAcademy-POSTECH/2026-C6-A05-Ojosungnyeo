//
//  ConfirmedPlacesBottomSheet.swift
//  ddaddo
//

import SwiftUI

struct ConfirmedPlacesBottomSheet: View {
    let participants: [PlaceSelectionFeature.Participant]
    let places: [PinnedPlace]
    let isEditing: Bool
    let editButtonTapped: () -> Void
    let deletePlace: (PinnedPlace) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 19)

            HStack(spacing: DDSpacing.xSmall) {
                ForEach(participants.filter(\.hasJoined)) { participant in
                    PlaceSelectionParticipantAvatar(
                        participant: participant,
                        isSelected: participant.isConfirmed
                    )
                }

                Spacer(minLength: DDSpacing.small)

                Button(isEditing ? "완료" : "편집", action: editButtonTapped)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.horizontal, DDSpacing.medium)
                    .frame(height: 34)
                    .background(DDColor.surfaceControl)
                    .clipShape(.capsule)
            }
            .padding(.top, 17)

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
                        ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                            ConfirmedPlaceTimelineRow(
                                number: index + 1,
                                place: place,
                                showsLineBelow: index < places.count - 1,
                                canDelete: isEditing,
                                deleteTapped: { deletePlace(place) }
                            )
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

private struct ConfirmedPlaceTimelineRow: View {
    private let deleteActionWidth: CGFloat = 72
    private let revealOffset: CGFloat = 84

    let number: Int
    let place: PinnedPlace
    let showsLineBelow: Bool
    let canDelete: Bool
    let deleteTapped: () -> Void

    @State private var horizontalOffset: CGFloat = 0
    @State private var settledOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: DDSpacing.medium) {
            timelineIndicator

            ZStack(alignment: .trailing) {
                if canDelete {
                    deleteButton
                }

                PlacePinCard(place: place)
                    .offset(x: horizontalOffset)
                    .gesture(swipeGesture)
                    .onTapGesture {
                        if settledOffset != 0 {
                            closeDeleteAction()
                        }
                    }
            }
            .frame(height: 72)
            .clipped()
        }
        .frame(height: 72)
        .onChange(of: canDelete) { _, isEnabled in
            if !isEnabled {
                closeDeleteAction()
            }
        }
    }

    private var timelineIndicator: some View {
        ZStack(alignment: .top) {
            if showsLineBelow {
                Rectangle()
                    .fill(DDColor.textTertiary)
                    .frame(width: 5, height: 84)
                    .offset(y: 7)
            }

            Circle()
                .fill(DDColor.actionPrimary)
                .frame(width: 15, height: 15)
                .overlay {
                    Text("\(number)")
                        .font(.custom("Pretendard-Medium", size: 10))
                        .foregroundStyle(DDColor.textOnPrimary)
                }
        }
        .frame(width: 18, height: 72, alignment: .top)
    }

    private var deleteButton: some View {
        Button {
            closeDeleteAction()
            deleteTapped()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DDColor.surfaceSelected)
                .frame(width: deleteActionWidth, height: 72)
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
                guard canDelete else { return }

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

    private func closeDeleteAction() {
        withAnimation(.snappy(duration: 0.2)) {
            horizontalOffset = 0
            settledOffset = 0
        }
    }
}
