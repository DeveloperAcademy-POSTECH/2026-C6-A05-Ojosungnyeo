//
//  RouteOverviewView.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct RouteOverviewView: View {
    let store: StoreOf<RouteOverviewFeature>
    var onBack: () -> Void = {
        // Preview and isolated usages can omit navigation handling.
    }
    @State private var isItineraryExpanded = false
    @State private var draggingStopID: RouteStop.ID?
    @State private var isTrashTargeted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                routeMap

                VStack(spacing: 0) {
                    tripNavigation
                    dayPicker
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                itineraryPanel(
                    fullHeight: max(560, proxy.size.height - 143)
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isEditing)
        .onAppear {
            isItineraryExpanded = false
            draggingStopID = nil
            isTrashTargeted = false
            store.send(.onAppear)
        }
        .preferredColorScheme(.dark)
    }

    private var routeMap: some View {
        RouteGoogleMapView(
            stops: store.visibleStops,
            selectedMembers: store.selectedMembers,
            selectedMemberOrder: store.selectedMemberOrder,
            currentMember: store.currentMember,
            memberOrder: store.memberOrder
        )
            .ignoresSafeArea()
    }

    private var tripNavigation: some View {
        ZStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

            VStack(spacing: 0) {
                Text("3박 4일 도쿄 여행")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
            }
        }
        .padding(.horizontal, DDSpacing.small)
        .frame(height: 40)
    }

    private var dayPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DDSpacing.small) {
                ForEach(TripDay.allCases) { day in
                    Button {
                        store.send(.daySelected(day))
                    } label: {
                        Text(day.rawValue)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.textPrimary)
                            .frame(width: 64, height: 40)
                            .background(day == store.selectedDay ? DDColor.surfaceControl : Color.clear)
                            .clipShape(.capsule)
                            .overlay {
                                Capsule()
                                    .stroke(
                                        day == store.selectedDay ? DDColor.actionPrimary : DDColor.borderDefault,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 17)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 8)
    }

    private func itineraryPanel(fullHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.textTertiary)
                .frame(width: 142, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            if store.isEditing {
                editingHeader
                    .padding(.top, 14)

                Text("여행 일정")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.top, 14)

                editingItineraryList
                    .padding(.top, 12)
            } else {
                memberFilter
                    .padding(.top, 14)

                Text("여행 일정")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.top, isItineraryExpanded ? 18 : 10)

                if isItineraryExpanded {
                    itineraryList
                        .padding(.top, 12)
                }
            }
        }
        .padding(.leading, 15)
        .padding(.trailing, DDSpacing.large)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(
            height: store.isEditing
                ? fullHeight
                : (isItineraryExpanded ? 413 : 139),
            alignment: .top
        )
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
        .contentShape(.rect)
        .gesture(
            store.isEditing
                ? nil
                : DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        if value.translation.height < -30 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isItineraryExpanded = true
                            }
                        } else if value.translation.height > 30 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isItineraryExpanded = false
                            }
                        }
                    }
        )
    }

    private var editingHeader: some View {
        HStack(spacing: DDSpacing.xSmall) {
            ForEach(store.memberOrder) { member in
                Button {
                    store.send(.memberTapped(member))
                } label: {
                    DDMiniHeadAvatar(character: member.routeAvatarCharacter, size: 37)
                        .opacity(
                            store.selectedMembers.isEmpty || store.selectedMembers.contains(member)
                                ? 1
                                : 0.35
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(member.accessibilityName) 일정 보기")
                .accessibilityValue(store.selectedMembers.contains(member) ? "선택됨" : "선택 안 됨")
            }

            Spacer(minLength: 0)

            Button("완료") {
                draggingStopID = nil
                isTrashTargeted = false
                store.send(.editingDoneButtonTapped)
            }
            .ddTypography(.bodyEmphasis16)
            .foregroundStyle(DDColor.textOnPrimary)
            .padding(.horizontal, DDSpacing.large)
            .frame(height: 34)
            .background(DDColor.actionPrimary)
            .clipShape(.capsule)
            .buttonStyle(.plain)
        }
    }

    private var memberFilter: some View {
        HStack(spacing: DDSpacing.xSmall) {
            ForEach(store.memberOrder) { member in
                Button {
                    store.send(.memberTapped(member))
                } label: {
                    DDMiniHeadAvatar(character: member.routeAvatarCharacter, size: 37)
                        .opacity(
                            store.selectedMembers.isEmpty || store.selectedMembers.contains(member)
                                ? 1
                                : 0.35
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(member.accessibilityName) 일정 보기")
                .accessibilityValue(store.selectedMembers.contains(member) ? "선택됨" : "선택 안 됨")
            }

            Spacer(minLength: 0)

            Button("편집") {
                store.send(.editButtonTapped)
            }
            .ddTypography(.bodyEmphasis16)
            .foregroundStyle(DDColor.textPrimary)
            .frame(width: 56, height: 34)
            .background(DDColor.surfaceControl)
            .clipShape(.capsule)
            .buttonStyle(.plain)
        }
    }

    private var itineraryList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(store.visibleStopGroups.enumerated()), id: \.element.id) { index, group in
                    HStack(alignment: .top, spacing: 20) {
                        timelineMarker(
                            index: index,
                            isLast: index == store.visibleStopGroups.count - 1
                        )

                        itineraryCards(for: group)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func itineraryCards(for group: RouteStopGroup) -> some View {
        if group.stops.count == 1 {
            stopCard(group.stops[0])
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(group.stops) { stop in
                        stopCard(stop)
                            .frame(width: 200)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0.82)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    private func stopCard(_ stop: RouteStop) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(stop.name)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                participantDots(for: stop)
            }

            Text(stop.category)
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .frame(maxWidth: .infinity, minHeight: 71, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.textTertiary, lineWidth: 1)
        }
    }

    private var editingItineraryList: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(store.visibleStopGroups.enumerated()), id: \.element.id) { index, group in
                        HStack(alignment: .top, spacing: 12) {
                            timelineMarker(index: index, isLast: false)
                            editingCards(for: group)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        timelineMarker(index: store.visibleStopGroups.count, isLast: true)

                        Button {
                        } label: {
                            Text("+ 장소 추가하기")
                                .ddTypography(.bodyEmphasis16)
                                .foregroundStyle(DDColor.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                                .padding(.horizontal, DDSpacing.xLarge)
                                .background(DDColor.surfaceElevated)
                                .clipShape(.rect(cornerRadius: 20))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(DDColor.actionPrimary, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, draggingStopID == nil ? 40 : 116)
            }
            .scrollIndicators(.hidden)

            if draggingStopID != nil {
                LinearGradient(
                    colors: [DDColor.surfaceDefault.opacity(0), DDColor.surfaceDefault],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 118)
                .allowsHitTesting(false)

                trashDropTarget
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: draggingStopID)
    }

    @ViewBuilder
    private func editingCards(for group: RouteStopGroup) -> some View {
        if group.stops.count == 1 {
            editingStopCard(group.stops[0])
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(group.stops) { stop in
                        editingStopCard(stop)
                            .frame(width: 200)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    private func editingStopCard(_ stop: RouteStop) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stop.name)
                        .ddTypography(.bodyEmphasis16)
                        .lineLimit(1)

                    participantDots(for: stop)
                }
                .foregroundStyle(DDColor.textPrimary)

                Text(stop.category)
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(DDColor.actionPrimary)
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DDColor.textSecondary)
                .frame(width: 28, height: 44)
                .accessibilityLabel("일정 순서 변경")
                .onDrag {
                    draggingStopID = stop.id
                    return NSItemProvider(object: String(stop.id) as NSString)
                }
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    draggingStopID == stop.id ? DDColor.actionPrimary : DDColor.textTertiary,
                    lineWidth: 1
                )
        }
        .onDrop(
            of: [UTType.text],
            delegate: RouteStopReorderDropDelegate(
                targetID: stop.id,
                draggedID: draggingStopID,
                move: { sourceID, targetID in
                    store.send(.editingStopMoved(sourceID, before: targetID))
                },
                finish: clearDragState
            )
        )
    }

    @ViewBuilder
    private func participantDots(for stop: RouteStop) -> some View {
        if store.selectedMembers.count != 1,
           !Set(store.memberOrder).isSubset(of: stop.members) {
            HStack(spacing: -5) {
                ForEach(members(for: stop)) { member in
                    Circle()
                        .fill(member.routeAccentColor)
                        .frame(width: 14, height: 14)
                }
            }
        }
    }

    private var trashDropTarget: some View {
        Image(systemName: "trash")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(DDColor.actionPrimary)
            .frame(width: 72, height: 58)
            .background(
                isTrashTargeted ? DDColor.surfaceControl : Color.clear,
                in: .capsule
            )
            .scaleEffect(isTrashTargeted ? 1.08 : 1)
            .accessibilityLabel("일정 삭제")
            .onDrop(
                of: [UTType.text],
                delegate: RouteTrashDropDelegate(
                    draggedID: draggingStopID,
                    isTargeted: $isTrashTargeted,
                    delete: { stopID in
                        store.send(.editingStopDeleted(stopID))
                    },
                    finish: clearDragState
                )
            )
    }

    private func clearDragState() {
        draggingStopID = nil
        isTrashTargeted = false
    }

    private func timelineMarker(index: Int, isLast: Bool) -> some View {
        ZStack(alignment: .top) {
            if !isLast {
                Rectangle()
                    .fill(DDColor.textTertiary)
                    .frame(width: 5, height: 92)
                    .offset(y: 7)
            }

            ZStack {
                Circle()
                    .fill(DDColor.actionPrimary)
                    .frame(width: 15, height: 15)

                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.black)
            }
        }
        .frame(width: 15, height: 71, alignment: .top)
    }

    private func members(for stop: RouteStop) -> [TripMember] {
        store.memberOrder.filter { member in
            stop.members.contains(member)
                && (store.selectedMembers.isEmpty || store.selectedMembers.contains(member))
        }
    }
}

private struct RouteStopReorderDropDelegate: DropDelegate {
    let targetID: RouteStop.ID
    let draggedID: RouteStop.ID?
    let move: (RouteStop.ID, RouteStop.ID) -> Void
    let finish: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != targetID else { return }
        move(draggedID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        finish()
        return true
    }
}

private struct RouteTrashDropDelegate: DropDelegate {
    let draggedID: RouteStop.ID?
    @Binding var isTargeted: Bool
    let delete: (RouteStop.ID) -> Void
    let finish: () -> Void

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedID else {
            finish()
            return false
        }

        delete(draggedID)
        finish()
        return true
    }
}

extension TripMember {
    var accessibilityName: String {
        switch self {
        case .tae: "테이"
        case .header: "헤더"
        case .grae: "그레"
        case .juni: "주니"
        }
    }

    var routeAvatarCharacter: DDMiniHeadAvatar.Character {
        switch self {
        case .tae: .tae
        case .header: .header
        case .grae: .grae
        case .juni: .juni
        }
    }

    var routeAccentColor: Color {
        switch self {
        case .tae: Color(red: 217 / 255.0, green: 149 / 255.0, blue: 126 / 255.0)
        case .header: Color(red: 152 / 255.0, green: 156 / 255.0, blue: 209 / 255.0)
        case .grae: Color(red: 102 / 255.0, green: 181 / 255.0, blue: 173 / 255.0)
        case .juni: Color(red: 197 / 255.0, green: 144 / 255.0, blue: 167 / 255.0)
        }
    }

    var routePolylineColor: Color {
        switch self {
        case .tae: Color(red: 192 / 255.0, green: 106 / 255.0, blue: 78 / 255.0)
        case .header: Color(red: 109 / 255.0, green: 114 / 255.0, blue: 189 / 255.0)
        case .grae: Color(red: 80 / 255.0, green: 117 / 255.0, blue: 113 / 255.0)
        case .juni: Color(red: 158 / 255.0, green: 107 / 255.0, blue: 130 / 255.0)
        }
    }

    var routeUFOAssetName: String {
        switch self {
        case .tae: "DDRouteUFOTae"
        case .header: "DDRouteUFOHeader"
        case .grae: "DDRouteUFOGrae"
        case .juni: "DDRouteUFOJuni"
        }
    }
}

#Preview {
    RouteOverviewView(
        store: Store(initialState: RouteOverviewFeature.State()) {
            RouteOverviewFeature()
        }
    )
}
