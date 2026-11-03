//
//  PlaceGroupingDetailView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct PlaceGroupingDetailView: View {
    let store: StoreOf<PlaceGroupingDetailFeature>
    var onBack: () -> Void = {}

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
        .animation(
            .easeInOut(duration: 0.2),
            value: store.isJoinConfirmationPresented
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
            HStack(alignment: .top, spacing: -14) {
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
                    PlaceSwipeRow(
                        place: place,
                        isEditable: store.canEditPlaces,
                        onDelete: { store.send(.deletePlaceTapped(place.id)) },
                        onMove: { sourceID in
                            store.send(
                                .placeMoved(
                                    sourceID: sourceID,
                                    beforeID: place.id
                                )
                            )
                        }
                    )
                }
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.bottom, DDSpacing.xLarge)
        }
        .scrollIndicators(.hidden)
    }

}

private struct PlaceSwipeRow: View {
    private let actionWidth: CGFloat = 58
    private let revealOffset: CGFloat = 70

    let place: PlaceGroupingDetailFeature.Place
    let isEditable: Bool
    let onDelete: () -> Void
    let onMove: (String) -> Void

    @State private var horizontalOffset: CGFloat = 0
    @State private var settledOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            if isEditable {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DDColor.actionPrimary)
                        .frame(width: actionWidth, height: 58)
                        .background(DDColor.actionSecondary)
                        .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            interactivePlaceCard
        }
        .frame(height: 58)
        .clipped()
        .onChange(of: isEditable) { _, isEditable in
            guard !isEditable else { return }
            horizontalOffset = 0
            settledOffset = 0
        }
    }

    @ViewBuilder
    private var interactivePlaceCard: some View {
        if isEditable {
            placeCard
                .offset(x: horizontalOffset)
                .gesture(swipeGesture)
                .draggable(place.id)
                .dropDestination(for: String.self) { items, _ in
                    guard let sourceID = items.first else { return false }
                    onMove(sourceID)
                    return true
                }
        } else {
            placeCard
        }
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

            if isEditable {
                dragHandle
            }
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
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(DDColor.iconDefault)
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                horizontalOffset = min(
                    0,
                    max(-revealOffset, settledOffset + value.translation.width)
                )
            }
            .onEnded { value in
                let predictedOffset = settledOffset + value.predictedEndTranslation.width
                let destination: CGFloat = predictedOffset < -(revealOffset / 2)
                    ? -revealOffset
                    : 0

                withAnimation(.snappy(duration: 0.25)) {
                    horizontalOffset = destination
                    settledOffset = destination
                }
            }
    }
}

#Preview {
    PlaceGroupingDetailView(
        store: Store(initialState: PlaceGroupingDetailFeature.State()) {
            PlaceGroupingDetailFeature()
        }
    )
}
