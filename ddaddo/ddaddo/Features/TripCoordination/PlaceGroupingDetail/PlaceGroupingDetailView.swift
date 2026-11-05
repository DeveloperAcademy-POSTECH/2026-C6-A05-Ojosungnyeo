//
//  PlaceGroupingDetailView.swift
//  ddaddo
//

import Combine
import ComposableArchitecture
import SwiftUI

private struct PlaceGroupingDropFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct PlaceGroupingDetailView: View {
    let store: StoreOf<PlaceGroupingDetailFeature>
    var onBack: () -> Void = {}

    @State private var draggingPlaceID: String?
    @State private var dragLocation: CGPoint?
    @State private var dropFrames: [String: CGRect] = [:]
    @State private var insertionBeforePlaceID: String?
    @State private var isAppendTargeted = false
    @State private var isTrashTargeted = false
    @State private var containerWidth: CGFloat = 0
    @State private var containerHeight: CGFloat = 0

    private enum AutoScrollDirection {
        case up
        case down
    }

    @State private var autoScrollDirection: AutoScrollDirection?
    private let appendTargetID = "placeGroupingAppendTarget"
    private let placeRowSpacing: CGFloat = 12
    private let trashTargetHeight: CGFloat = 81
    private let autoScrollTimer = Timer.publish(
        every: 0.16,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            DDColor.surfaceDefault
                .ignoresSafeArea()

            VStack(spacing: 0) {
                tripNavigation
                groupHeading
                memberList
                preferenceHeading
                if store.canJoin && !store.showsEmptyState {
                    joinButton
                }
                if store.showsEmptyState {
                    emptyState
                } else {
                    placeList
                }
            }

            if store.isJoinConfirmationPresented {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(3)

                DDConfirmationAlert(
                    title: "합류하시겠어요?",
                    message: "지금까지 담은 일정이 초기화돼요.\n그래도 합류하시겠어요?",
                    cancelTitle: "아니요",
                    confirmTitle: "네",
                    onCancel: {
                        store.send(.joinConfirmationCancelTapped)
                    },
                    onConfirm: {
                        store.send(.joinConfirmationConfirmTapped)
                    }
                )
                .frame(maxHeight: .infinity)
                .zIndex(4)
            }

            if store.isDeleteConfirmationPresented {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(5)

                DDConfirmationAlert(
                    title: "장소 삭제하기",
                    message: "이 장소를 진짜 삭제할까요?",
                    cancelTitle: "아니요",
                    confirmTitle: "네",
                    cancelColor: DDColor.actionPrimary,
                    onCancel: {
                        store.send(.deleteConfirmationCancelTapped)
                    },
                    onConfirm: {
                        store.send(.deleteConfirmationConfirmTapped)
                    }
                )
                .frame(maxHeight: .infinity)
                .zIndex(6)
            }

        }
        .coordinateSpace(name: "placeGroupingDetailDrag")
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DDCTAButton(title: "확정하기") {
                store.send(.confirmButtonTapped)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, DDSpacing.xLarge)
            .padding(.bottom, 11)
            .background(DDColor.surfaceDefault)
        }
        .overlay(alignment: .bottom) {
            if draggingPlaceID != nil {
                trashDropOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .overlay {
            if let draggingPlaceID,
               let dragLocation,
               let place = store.places.first(where: { $0.id == draggingPlaceID }) {
                PlaceDragPreview(place: place)
                    .frame(width: max(0, containerWidth - 32), height: 58)
                    .position(x: containerWidth / 2, y: dragLocation.y)
                    .allowsHitTesting(false)
                    .zIndex(11)
            }
        }
        .onPreferenceChange(PlaceGroupingDropFramesKey.self) { frames in
            dropFrames = frames
            if let dragLocation {
                updateAutoScrollDirection(at: dragLocation)
                updateDropTarget(at: dragLocation)
            }
        }
        .animation(
            .easeInOut(duration: 0.2),
            value: store.isJoinConfirmationPresented
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: store.isDeleteConfirmationPresented
        )
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var tripNavigation: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Text(store.tripTitle)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)

                Text(store.tripDates)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
            }

            HStack {
                Button {
                    onBack()
                } label: {
                    ZStack(alignment: .topLeading) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 25, weight: .regular))
                            .padding(.top, 4)
                    }
                    .frame(width: 44, height: 44, alignment: .topLeading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .foregroundStyle(DDColor.textPrimary)
            .padding(.horizontal, DDSpacing.large)
        }
        .frame(height: 51, alignment: .top)
    }

    private var groupHeading: some View {
        HStack(spacing: DDSpacing.xSmall) {
            Text(store.groupTitle)
                .ddTypography(.title24)

            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .bold))

            Spacer(minLength: 0)
        }
        .foregroundStyle(DDColor.textPrimary)
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 44, alignment: .top)
    }

    private var memberList: some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(alignment: .top, spacing: -22) {
                ForEach(Array(groupMembers.enumerated()), id: \.element.id) { index, member in
                    memberButton(
                        member,
                        isActive: store.selectedMemberIDs.contains(member.id)
                    )
                    .zIndex(Double(groupMembers.count - index))
                }
            }

            ForEach(individualMembers) { member in
                memberButton(
                    member,
                    isActive: store.selectedMemberIDs.contains(member.id)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 109, alignment: .top)
    }

    private var groupMembers: [PlaceGroupingDetailFeature.Member] {
        store.members.filter { store.groupMemberIDs.contains($0.id) }
    }

    private var individualMembers: [PlaceGroupingDetailFeature.Member] {
        store.members.filter { !store.groupMemberIDs.contains($0.id) }
    }

    private func memberButton(
        _ member: PlaceGroupingDetailFeature.Member,
        isActive: Bool
    ) -> some View {
        Button {
            store.send(.memberTapped(member.id))
        } label: {
            memberAvatar(member, isActive: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(member.name) 장소 보기")
        .accessibilityValue(isActive ? "선택됨" : "선택 안 됨")
    }

    private func memberAvatar(
        _ member: PlaceGroupingDetailFeature.Member,
        isActive: Bool
    ) -> some View {
        VStack(spacing: 3) {
            DDMiniHeadAvatar(character: member.character, size: 56)
                .opacity(isActive ? 1 : 0.5)

            Text(displayName(member.name))
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
                .opacity(isActive ? 1 : 0.5)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 56, alignment: .top)
        }
        .frame(width: 56)
    }

    private func displayName(_ name: String) -> String {
        let characters = Array(name)
        guard characters.count > 3 else { return name }

        return String(characters.prefix(3))
            + "\n"
            + String(characters.dropFirst(3))
    }

    private var joinButton: some View {
        HStack {
            Button("합류하기") {
                store.send(.joinButtonTapped)
            }
            .ddTypography(.labelEmphasis14)
            .foregroundStyle(DDColor.textOnPrimary)
            .padding(.horizontal, 10)
            .frame(height: 29)
            .background(DDColor.actionPrimary)
            .clipShape(.capsule)
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.bottom, 10)
    }

    private var preferenceHeading: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("꼭 방문하고 싶은 장소")
                .ddTypography(.heading18)
                .foregroundStyle(DDColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .topLeading)

            if !store.showsEmptyState {
                preferenceDescription
                    .ddTypography(.body16)
                    .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 71, alignment: .top)
    }

    private var emptyState: some View {
        VStack(spacing: DDSpacing.large) {
            Image("Empty")
                .resizable()
                .scaledToFit()
                .frame(width: 159, height: 170)

            Text("\(emptyStateMemberName)는 이 지역에 그룹핑된 장소가 없어요")
                .ddTypography(.body16)
                .foregroundStyle(DDColor.borderSubtle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 76)
    }

    private var emptyStateMemberName: String {
        store.members.first(where: { store.selectedMemberIDs.contains($0.id) })?.name
            ?? store.members.first?.name
            ?? "선택한 멤버"
    }

    private var preferenceDescription: Text {
        let categories = store.preferenceCategories
        guard !categories.isEmpty else {
            return Text("비슷한 취향으로 모인 그룹이에요")
                .foregroundColor(DDColor.textSecondary)
        }

        var result = Text("")
        for (index, category) in categories.enumerated() {
            if index > 0 {
                let separator = index == categories.count - 1 ? " 그리고 " : ", "
                result = result + Text(separator).foregroundColor(DDColor.textSecondary)
            }
            result = result + Text(category)
                .font(.custom("Pretendard-SemiBold", size: 16, relativeTo: .body))
                .foregroundColor(DDColor.actionPrimary)
        }

        return result
            + Text(" 취향으로 모인 그룹이에요")
                .foregroundColor(DDColor.textSecondary)
    }

    private var placeList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: placeRowSpacing) {
                    ForEach(store.places) { place in
                        PlaceDraggableRow(
                            place: place,
                            isEditable: store.canEditPlaces,
                            onDragChanged: { location in
                                draggingPlaceID = place.id
                                dragLocation = verticalDragLocation(from: location)
                                updateAutoScrollDirection(at: location)
                                updateDropTarget(at: location)
                            },
                            onDragEnded: { location in
                                dragLocation = verticalDragLocation(from: location)
                                updateAutoScrollDirection(at: location)
                                updateDropTarget(at: location)
                                commitDrop()
                            }
                        )
                        .id(place.id)
                        .opacity(draggingPlaceID == place.id ? 0.35 : 1)
                        .background(dropFrame("row:\(place.id)"))
                        .overlay(alignment: .top) {
                            if draggingPlaceID != nil {
                                insertionDropArea(before: place.id)
                                    .offset(
                                        y: -(
                                            DDSpacing.xLarge / 2
                                                + placeRowSpacing / 2
                                        )
                                    )
                            }
                        }
                    }

                    if draggingPlaceID != nil {
                        appendDropArea
                            .id(appendTargetID)
                    }
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.xLarge)
            }
            .background(dropFrame("list"))
            .onReceive(autoScrollTimer) { _ in
                autoScroll(using: proxy)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func dropFrame(_ id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: PlaceGroupingDropFramesKey.self,
                value: [id: proxy.frame(in: .named("placeGroupingDetailDrag"))]
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

        if let insertionTarget = store.places.first(where: {
            dropFrames["insert:\($0.id)"]?.contains(location) == true
        })?.id {
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

        if let rowIndex = store.places.firstIndex(where: {
            dropFrames["row:\($0.id)"]?.contains(location) == true
        }), let rowFrame = dropFrames["row:\(store.places[rowIndex].id)"] {
            if location.y < rowFrame.midY {
                insertionBeforePlaceID = store.places[rowIndex].id
                isAppendTargeted = false
            } else if store.places.indices.contains(rowIndex + 1) {
                insertionBeforePlaceID = store.places[rowIndex + 1].id
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

    private func commitDrop() {
        defer { finishDrag() }
        guard let draggingPlaceID else { return }

        if isTrashTargeted {
            store.send(.deletePlaceTapped(draggingPlaceID))
        } else if let insertionBeforePlaceID {
            store.send(.placeMoved(sourceID: draggingPlaceID, beforeID: insertionBeforePlaceID))
        } else if isAppendTargeted {
            store.send(.placeMoved(sourceID: draggingPlaceID, beforeID: nil))
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

    private func verticalDragLocation(from location: CGPoint) -> CGPoint {
        CGPoint(x: containerWidth / 2, y: location.y)
    }

    private func insertionDropArea(before placeID: String) -> some View {
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

    private var trashDropOverlay: some View {
        LinearGradient(
            colors: [.clear, Color.black.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: min(trashTargetHeight, containerHeight))
        .overlay {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DDColor.actionPrimary)
                .frame(width: 56, height: 56)
                .scaleEffect(isTrashTargeted ? 1.15 : 1)
                .animation(.easeInOut(duration: 0.15), value: isTrashTargeted)
        }
        .background(dropFrame("trash"))
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }

    private var trashTargetFrame: CGRect {
        CGRect(
            x: 0,
            y: max(0, containerHeight - trashTargetHeight),
            width: containerWidth,
            height: trashTargetHeight
        )
    }

    private func updateAutoScrollDirection(at location: CGPoint) {
        guard let listFrame = dropFrames["list"] else {
            autoScrollDirection = nil
            return
        }

        let topEdgeThreshold: CGFloat = 52
        let bottomEdgeThreshold: CGFloat = 120
        let trashBoundary = containerHeight - trashTargetHeight
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
        let visibleIndices = store.places.indices.filter { index in
            guard let frame = dropFrames["row:\(store.places[index].id)"] else {
                return false
            }
            return frame.intersects(listFrame)
        }

        guard let firstVisibleIndex = visibleIndices.first,
              let lastVisibleIndex = visibleIndices.last
        else { return false }

        switch direction {
        case .up:
            return firstVisibleIndex > store.places.startIndex
        case .down:
            if lastVisibleIndex < store.places.index(before: store.places.endIndex) {
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

        let visibleIndices = store.places.indices.filter { index in
            guard let frame = dropFrames["row:\(store.places[index].id)"] else {
                return false
            }
            return frame.intersects(listFrame)
        }

        let targetID: String
        let targetAnchor: UnitPoint
        switch autoScrollDirection {
        case .up:
            guard let firstVisibleIndex = visibleIndices.first,
                  firstVisibleIndex > store.places.startIndex
            else {
                self.autoScrollDirection = nil
                return
            }
            targetID = store.places[store.places.index(before: firstVisibleIndex)].id
            targetAnchor = .top
        case .down:
            guard let lastVisibleIndex = visibleIndices.last else {
                self.autoScrollDirection = nil
                return
            }
            if lastVisibleIndex < store.places.index(before: store.places.endIndex) {
                targetID = store.places[store.places.index(after: lastVisibleIndex)].id
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

private struct PlaceDraggableRow: View {
    let place: PlaceGroupingDetailFeature.Place
    let isEditable: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void

    var body: some View {
        placeCard
            .frame(height: 58)
    }

    private var placeCard: some View {
        HStack(spacing: DDSpacing.large) {
            Group {
                if let data = place.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let image = UIImage(named: place.imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    DDColor.surfaceControl
                        .overlay {
                            Image("DDEarth")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35, height: 33)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(.rect(cornerRadius: 8))

            Text(place.title)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)

            Spacer(minLength: 0)

            dragHandle
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var dragHandle: some View {
        HStack(spacing: 3.39) {
            verticalEllipsis
            verticalEllipsis
        }
        .frame(width: 12, height: 22)
        .frame(width: 44, height: 44, alignment: .trailing)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(
                minimumDistance: 0,
                coordinateSpace: .named("placeGroupingDetailDrag")
            )
                .onChanged { drag in
                    guard isEditable else { return }
                    onDragChanged(drag.location)
                }
                .onEnded { drag in
                    guard isEditable else { return }
                    onDragEnded(drag.location)
                }
        )
        .accessibilityHidden(true)
    }

    private var verticalEllipsis: some View {
        Image(systemName: "ellipsis")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 4)
            .rotationEffect(.degrees(90))
            .frame(width: 4, height: 18)
            .foregroundStyle(Color(red: 222 / 255, green: 222 / 255, blue: 222 / 255))
    }
}

private struct PlaceDragPreview: View {
    let place: PlaceGroupingDetailFeature.Place

    var body: some View {
        HStack(spacing: DDSpacing.large) {
            Group {
                if let data = place.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if let image = UIImage(named: place.imageName) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    DDColor.surfaceControl
                        .overlay {
                            Image("DDEarth")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35, height: 33)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(.rect(cornerRadius: 8))

            Text(place.title)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58)
        .background(DDColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
    }
}

#Preview {
    PlaceGroupingDetailView(
        store: Store(initialState: PlaceGroupingDetailFeature.State()) {
            PlaceGroupingDetailFeature()
        }
    )
}
