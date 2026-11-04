//
//  MemberPlacesBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

private struct MemberPlaceDropFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct MemberPlacesBottomSheet: View {
    let isExpanded: Bool
    let selectedMember: TripMember
    let participants: [PlaceSelectionFeature.Participant]
    let places: [PinnedPlace]
    let canDeletePlaces: Bool
    let canConfirm: Bool
    let showsConfirmationButton: Bool
    let isConfirmationComplete: Bool
    var bottomContentInset: CGFloat = DDSpacing.xLarge
    let memberTapped: (TripMember) -> Void
    let placeTapped: (PinnedPlace) -> Void
    let deletePlace: (PinnedPlace) -> Void
    let movePlace: (PinnedPlace.ID, PinnedPlace.ID) -> Void
    let confirmButtonTapped: () -> Void

    @State private var draggingPlaceID: PinnedPlace.ID?
    @State private var dragLocation: CGPoint?
    @State private var dropFrames: [String: CGRect] = [:]
    @State private var targetedPlaceID: PinnedPlace.ID?
    @State private var isTrashTargeted = false
    @State private var containerWidth: CGFloat = 0
    @State private var containerHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
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
                        emptyState

                        Spacer(minLength: bottomContentInset)
                    } else {
                        placeList
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, DDSpacing.large)

            if draggingPlaceID != nil {
                trashDropOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }

            if let draggingPlaceID,
               let dragLocation,
               let place = places.first(where: { $0.id == draggingPlaceID }) {
                PlacePinCard(place: place)
                    .frame(width: max(0, containerWidth - 32), height: 72)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
                    .position(x: containerWidth / 2, y: dragLocation.y)
                    .allowsHitTesting(false)
                    .zIndex(11)
            }
        }
        .coordinateSpace(name: "memberPlacesDrag")
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        containerWidth = proxy.size.width
                        containerHeight = proxy.size.height
                    }
                    .onChange(of: proxy.size) { _, size in
                        containerWidth = size.width
                        containerHeight = size.height
                    }
            }
        }
        .onPreferenceChange(MemberPlaceDropFramesKey.self) { dropFrames = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private var memberSelector: some View {
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

            Spacer(minLength: DDSpacing.small)

            if showsConfirmationButton {
                Button(
                    isConfirmationComplete ? "확정완료" : "확정하기",
                    action: confirmButtonTapped
                )
                .font(.custom("Pretendard-Bold", size: 14, relativeTo: .subheadline))
                .foregroundStyle(
                    isConfirmationComplete || canConfirm
                        ? DDColor.textOnPrimary
                        : DDColor.textTertiary
                )
                .padding(.horizontal, DDSpacing.medium)
                .frame(height: 28)
                .background(
                    isConfirmationComplete || canConfirm
                        ? DDColor.actionPrimary
                        : DDColor.surfaceControl
                )
                .clipShape(.capsule)
                .disabled(isConfirmationComplete || !canConfirm)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DDSpacing.large) {
            Image("Empty")
                .resizable()
                .frame(width: 103.2, height: 125.2)

            Text("아직 핀 찍힌 장소가 없어요")
                .ddTypography(.body16)
                .foregroundStyle(DDColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 74)
    }

    private var placeList: some View {
        ScrollView {
            LazyVStack(spacing: DDSpacing.medium) {
                ForEach(places) { place in
                    PlacePinCard(
                        place: place,
                        showsDragHandle: canDeletePlaces,
                        onDragChanged: { location in
                            guard canDeletePlaces else { return }
                            let location = verticalDragLocation(from: location)
                            draggingPlaceID = place.id
                            dragLocation = location
                            updateDropTarget(at: location)
                        },
                        onDragEnded: { location in
                            guard canDeletePlaces else { return }
                            let location = verticalDragLocation(from: location)
                            dragLocation = location
                            updateDropTarget(at: location)
                            commitDrop()
                        }
                    )
                    .overlay {
                        if targetedPlaceID == place.id {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(DDColor.actionPrimary.opacity(0.12))
                                .allowsHitTesting(false)
                        }
                    }
                    .opacity(draggingPlaceID == place.id ? 0.35 : 1)
                    .contentShape(.rect)
                    .onTapGesture { placeTapped(place) }
                    .background(dropFrame("row:\(place.id)"))
                }

                Color.clear
                    .frame(height: bottomContentInset)
            }
        }
        .scrollIndicators(.hidden)
        .padding(.top, DDSpacing.xLarge)
    }

    private var trashDropOverlay: some View {
        LinearGradient(
            colors: [.clear, Color.black.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: min(246, containerHeight))
        .overlay(alignment: .bottom) {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DDColor.actionPrimary)
                .frame(width: 56, height: 56)
                .scaleEffect(isTrashTargeted ? 1.15 : 1)
                .padding(.bottom, 22)
                .animation(.easeInOut(duration: 0.15), value: isTrashTargeted)
        }
        .allowsHitTesting(false)
    }

    private func dropFrame(_ id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: MemberPlaceDropFramesKey.self,
                value: [id: proxy.frame(in: .named("memberPlacesDrag"))]
            )
        }
    }

    private func updateDropTarget(at location: CGPoint) {
        isTrashTargeted = containerHeight > 0 && location.y >= containerHeight - 124
        targetedPlaceID = isTrashTargeted
            ? nil
            : places.first(where: {
                $0.id != draggingPlaceID
                    && dropFrames["row:\($0.id)"]?.contains(location) == true
            })?.id
    }

    private func verticalDragLocation(from location: CGPoint) -> CGPoint {
        CGPoint(x: containerWidth / 2, y: location.y)
    }

    private func commitDrop() {
        defer { finishDrag() }
        guard let draggingPlaceID,
              let draggedPlace = places.first(where: { $0.id == draggingPlaceID })
        else { return }

        if isTrashTargeted {
            deletePlace(draggedPlace)
        } else if let targetedPlaceID {
            movePlace(draggingPlaceID, targetedPlaceID)
        }
    }

    private func finishDrag() {
        withAnimation(.easeOut(duration: 0.18)) {
            draggingPlaceID = nil
            dragLocation = nil
            targetedPlaceID = nil
            isTrashTargeted = false
        }
    }
}
