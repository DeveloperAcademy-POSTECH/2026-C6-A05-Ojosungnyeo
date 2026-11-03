//
//  PlaceGroupingDetailView.swift
//  ddaddo
//

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
    @State private var targetedPlaceID: String?
    @State private var isTrashTargeted = false
    @State private var containerHeight: CGFloat = 0

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
                    .onAppear { containerHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, height in
                        containerHeight = height
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
                    .frame(width: 370, height: 58)
                    .position(dragLocation)
                    .allowsHitTesting(false)
                    .zIndex(11)
            }
        }
        .onPreferenceChange(PlaceGroupingDropFramesKey.self) { dropFrames = $0 }
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
                    Image(systemName: "chevron.left")
                        .font(.system(size: 25, weight: .regular))
                        .frame(width: 44, height: 44, alignment: .leading)
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
            HStack(alignment: .top, spacing: -29) {
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
        VStack(spacing: 0) {
            DDMiniHeadAvatar(character: member.character, size: 56)
                .opacity(isActive ? 1 : 0.5)

            Text(member.name)
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
                .opacity(isActive ? 1 : 0.5)
        }
        .frame(width: 56)
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

            if !store.showsEmptyState {
                preferenceDescription
                    .ddTypography(.body16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 71, alignment: .top)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("휑")
                .font(.system(size: 128, weight: .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(1)
                .frame(height: 122)

            Text("\(emptyStateMemberName)는 이 지역에 그룹핑된 장소가 없어요")
                .ddTypography(.body16)
                .foregroundStyle(DDColor.textPrimary)
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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.places) { place in
                    PlaceDraggableRow(
                        place: place,
                        isEditable: store.canEditPlaces,
                        isTargeted: targetedPlaceID == place.id,
                        onDragChanged: { location in
                            draggingPlaceID = place.id
                            dragLocation = location
                            updateDropTarget(at: location)
                        },
                        onDragEnded: { location in
                            dragLocation = location
                            updateDropTarget(at: location)
                            commitDrop()
                        }
                    )
                    .background(dropFrame("row:\(place.id)"))
                }
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.bottom, DDSpacing.xLarge)
        }
        .scrollIndicators(.hidden)
    }

    private var trashDropOverlay: some View {
        LinearGradient(
            colors: [.clear, Color.black.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 246)
        .overlay(alignment: .bottom) {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DDColor.actionPrimary)
                .frame(width: 56, height: 56)
                .scaleEffect(isTrashTargeted ? 1.15 : 1)
                .padding(.bottom, 22)
                .animation(.easeInOut(duration: 0.15), value: isTrashTargeted)
        }
        .background(alignment: .bottom) {
            Color.clear
                .frame(height: 124)
                .background(dropFrame("trash"))
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
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
        isTrashTargeted = containerHeight > 0 && location.y >= containerHeight - 124
        targetedPlaceID = isTrashTargeted
            ? nil
            : store.places.first(where: {
                $0.id != draggingPlaceID &&
                dropFrames["row:\($0.id)"]?.contains(location) == true
            })?.id
    }

    private func commitDrop() {
        defer { finishDrag() }
        guard let draggingPlaceID else { return }

        if isTrashTargeted {
            store.send(.deletePlaceTapped(draggingPlaceID))
        } else if let targetedPlaceID {
            store.send(.placeMoved(sourceID: draggingPlaceID, beforeID: targetedPlaceID))
        }
    }

    private func finishDrag() {
        draggingPlaceID = nil
        dragLocation = nil
        targetedPlaceID = nil
        isTrashTargeted = false
    }

}

private struct PlaceDraggableRow: View {
    let place: PlaceGroupingDetailFeature.Place
    let isEditable: Bool
    let isTargeted: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void

    var body: some View {
        placeCard
        .frame(height: 58)
        .background(isTargeted ? DDColor.actionPrimary.opacity(0.12) : .clear)
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
                    Color(red: 52 / 255, green: 52 / 255, blue: 52 / 255)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(DDColor.textSecondary)
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
