//
//  MemberPlacesBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import Combine
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
    let movePlace: (PinnedPlace.ID, PinnedPlace.ID?) -> Void
    let confirmButtonTapped: () -> Void

    @State private var draggingPlaceID: PinnedPlace.ID?
    @State private var dragLocation: CGPoint?
    @State private var dropFrames: [String: CGRect] = [:]
    @State private var insertionBeforePlaceID: PinnedPlace.ID?
    @State private var isAppendTargeted = false
    @State private var isTrashTargeted = false
    @State private var containerWidth: CGFloat = 0
    @State private var containerHeight: CGFloat = 0

    private enum AutoScrollDirection {
        case up
        case down
    }

    @State private var autoScrollDirection: AutoScrollDirection?
    private let appendTargetID = "memberPlacesAppendTarget"
    private let autoScrollTimer = Timer.publish(
        every: 0.16,
        on: .main,
        in: .common
    ).autoconnect()

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
                    .zIndex(12)
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
        .onPreferenceChange(MemberPlaceDropFramesKey.self) { frames in
            dropFrames = frames
            if let dragLocation {
                updateAutoScrollDirection(at: dragLocation)
                updateDropTarget(at: dragLocation)
            }
        }
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: DDSpacing.medium) {
                    ForEach(places) { place in
                        PlacePinCard(
                            place: place,
                            showsDragHandle: canDeletePlaces,
                            onDragChanged: { location in
                                guard canDeletePlaces else { return }
                                draggingPlaceID = place.id
                                dragLocation = verticalDragLocation(from: location)
                                updateAutoScrollDirection(at: location)
                                updateDropTarget(at: location)
                            },
                            onDragEnded: { location in
                                guard canDeletePlaces else { return }
                                dragLocation = verticalDragLocation(from: location)
                                updateAutoScrollDirection(at: location)
                                updateDropTarget(at: location)
                                commitDrop()
                            }
                        )
                        .id(place.id)
                        .opacity(draggingPlaceID == place.id ? 0.35 : 1)
                        .contentShape(.rect)
                        .onTapGesture { placeTapped(place) }
                        .background(dropFrame("row:\(place.id)"))
                        .overlay(alignment: .top) {
                            if draggingPlaceID != nil {
                                insertionDropArea(before: place.id)
                                    .offset(
                                        y: -(
                                            DDSpacing.xLarge / 2
                                                + DDSpacing.medium / 2
                                        )
                                    )
                            }
                        }
                    }

                    if draggingPlaceID != nil {
                        appendDropArea
                            .id(appendTargetID)
                    }

                    Color.clear
                        .frame(height: bottomContentInset)
                }
            }
            .background(dropFrame("list"))
            .onReceive(autoScrollTimer) { _ in
                autoScroll(using: proxy)
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
        .frame(height: min(81, containerHeight))
        .overlay {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DDColor.actionPrimary)
                .frame(width: 56, height: 56)
                .scaleEffect(isTrashTargeted ? 1.15 : 1)
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
        if trashTargetFrame.contains(location) {
            insertionBeforePlaceID = nil
            isAppendTargeted = false
            isTrashTargeted = true
            return
        }

        let insertionTarget = places.first(where: {
            dropFrames["insert:\($0.id)"]?.contains(location) == true
        })?.id

        if let insertionTarget {
            insertionBeforePlaceID = insertionTarget
            isAppendTargeted = false
            isTrashTargeted = false
            return
        }

        if dropFrames["append"]?.contains(location) == true {
            insertionBeforePlaceID = nil
            isAppendTargeted = true
            isTrashTargeted = false
            return
        }

        if let rowIndex = places.firstIndex(where: {
            dropFrames["row:\($0.id)"]?.contains(location) == true
        }), let rowFrame = dropFrames["row:\(places[rowIndex].id)"] {
            if location.y < rowFrame.midY {
                insertionBeforePlaceID = places[rowIndex].id
                isAppendTargeted = false
            } else if places.indices.contains(rowIndex + 1) {
                insertionBeforePlaceID = places[rowIndex + 1].id
                isAppendTargeted = false
            } else {
                insertionBeforePlaceID = nil
                isAppendTargeted = true
            }
            isTrashTargeted = false
            return
        }

        insertionBeforePlaceID = nil
        isAppendTargeted = false
        isTrashTargeted = trashTargetFrame.contains(location)
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
        } else if let insertionBeforePlaceID {
            movePlace(draggingPlaceID, insertionBeforePlaceID)
        } else if isAppendTargeted {
            movePlace(draggingPlaceID, nil)
        }
    }

    private func finishDrag() {
        withAnimation(.easeOut(duration: 0.18)) {
            draggingPlaceID = nil
            dragLocation = nil
            insertionBeforePlaceID = nil
            isAppendTargeted = false
            isTrashTargeted = false
            autoScrollDirection = nil
        }
    }

    private func insertionDropArea(before placeID: PinnedPlace.ID) -> some View {
        ZStack {
            if insertionBeforePlaceID == placeID {
                insertionIndicator
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: DDSpacing.xLarge)
        .contentShape(.rect)
        .background(dropFrame("insert:\(placeID)"))
    }

    private var appendDropArea: some View {
        ZStack {
            if isAppendTargeted {
                insertionIndicator
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: DDSpacing.xLarge)
        .contentShape(.rect)
        .background(dropFrame("append"))
    }

    private var insertionIndicator: some View {
        Capsule()
            .fill(DDColor.actionPrimary)
            .frame(height: 2)
    }

    private var trashTargetFrame: CGRect {
        CGRect(
            x: 0,
            y: max(0, containerHeight - 64),
            width: containerWidth,
            height: .greatestFiniteMagnitude
        )
    }

    private func updateAutoScrollDirection(at location: CGPoint) {
        guard let listFrame = dropFrames["list"] else {
            autoScrollDirection = nil
            return
        }

        let topEdgeThreshold: CGFloat = 52
        let bottomEdgeThreshold: CGFloat = 120
        let trashBoundary = containerHeight - 64
        if location.y <= listFrame.minY + topEdgeThreshold,
           canAutoScroll(.up, in: listFrame) {
            autoScrollDirection = .up
        } else if location.y >= listFrame.maxY - bottomEdgeThreshold,
                  location.y < trashBoundary,
                  canAutoScroll(.down, in: listFrame) {
            autoScrollDirection = .down
        } else {
            autoScrollDirection = nil
        }
    }

    private func canAutoScroll(
        _ direction: AutoScrollDirection,
        in listFrame: CGRect
    ) -> Bool {
        let visibleIndices = places.indices.filter { index in
            guard let frame = dropFrames["row:\(places[index].id)"] else {
                return false
            }
            return frame.intersects(listFrame)
        }

        guard let firstVisibleIndex = visibleIndices.first,
              let lastVisibleIndex = visibleIndices.last
        else { return false }

        switch direction {
        case .up:
            return firstVisibleIndex > places.startIndex
        case .down:
            if lastVisibleIndex < places.index(before: places.endIndex) {
                return true
            }
            guard let appendFrame = dropFrames["append"] else { return true }
            return !appendFrame.intersects(listFrame)
        }
    }

    private func autoScroll(using proxy: ScrollViewProxy) {
        guard let autoScrollDirection,
              let listFrame = dropFrames["list"]
        else { return }

        let visibleIndices = places.indices.filter { index in
            guard let frame = dropFrames["row:\(places[index].id)"] else {
                return false
            }
            return frame.intersects(listFrame)
        }

        let targetID: String
        let targetAnchor: UnitPoint
        switch autoScrollDirection {
        case .up:
            guard let firstVisibleIndex = visibleIndices.first,
                  firstVisibleIndex > places.startIndex
            else {
                self.autoScrollDirection = nil
                return
            }
            targetID = places[places.index(before: firstVisibleIndex)].id
            targetAnchor = .top
        case .down:
            guard let lastVisibleIndex = visibleIndices.last else {
                self.autoScrollDirection = nil
                return
            }
            if lastVisibleIndex < places.index(before: places.endIndex) {
                targetID = places[places.index(after: lastVisibleIndex)].id
                targetAnchor = .bottom
            } else {
                targetID = appendTargetID
                targetAnchor = .center
            }
        }

        withAnimation(.linear(duration: 0.14)) {
            proxy.scrollTo(targetID, anchor: targetAnchor)
        }
    }
}
