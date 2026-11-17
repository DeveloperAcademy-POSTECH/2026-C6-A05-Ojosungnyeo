import ComposableArchitecture
import SwiftUI

private struct TimeTableDropFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct TimeTableEditView: View {
    let timeTableStore: StoreOf<TimeTableFeature>
    let store: StoreOf<TimeTableEditFeature>

    var body: some View {
        TimeTableEditContent(timeTableStore: timeTableStore, store: store)
        .sheet(
            isPresented: Binding(
                get: { store.isAddSchedulePresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.addScheduleDismissed)
                    }
                }
            )
        ) {
            AddScheduleBottomSheet(store: store)
                .presentationDetents([.height(395), .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
                .presentationBackground(DDColor.surfaceDefault)
        }
        .sheet(
            isPresented: Binding(
                get: { store.isTimeSelectionPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.timeSelectionDismissed)
                    }
                }
            )
        ) {
            TimeSelectionBottomSheet(
                selectedMinuteOfDay: Binding(
                    get: { store.selectedMinuteOfDay ?? 0 },
                    set: { store.send(.timeSelectionChanged($0)) }
                ),
                canConfirm: timeTableStore.canConfirmTimeSelection,
                showsOverlapError: timeTableStore.hasTimeSelectionConflict,
                onDone: { store.send(.timeSelectionDoneTapped) }
            )
            .presentationDetents([.height(424)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
            .presentationBackground(DDColor.surfaceDefault)
        }
        .allowsHitTesting(
            store.pendingDeletion == nil && !store.isSaveUnavailableAlertPresented
        )
        .overlay {
            if store.pendingDeletion != nil {
                DDAlertOverlay(
                    title: "일정을 삭제할까요?",
                    message: "삭제한 일정은 여행 일정에서 사라져요.",
                    cancelTitle: "아니요",
                    confirmTitle: "네",
                    confirmColor: DDColor.alertDestructive,
                    onCancel: { store.send(.deletionCancelled) },
                    onConfirm: { store.send(.deletionConfirmed) }
                )
            } else if store.isSaveUnavailableAlertPresented {
                DDAlertOverlay(
                    title: "일정을 저장할 수 없어요",
                    message: store.saveErrorMessage,
                    confirmTitle: "확인",
                    onConfirm: { store.send(.saveUnavailableAlertDismissed) }
                )
            }
        }
    }
}

private struct TimeTableEditContent: View {
    let timeTableStore: StoreOf<TimeTableFeature>
    let store: StoreOf<TimeTableEditFeature>

    @State private var dragging: DraggedItem?
    @State private var targetedRowID: String?
    @State private var isAppendTargeted = false
    @State private var isDeletionOverlayPresented = false
    @State private var dragLocation: CGPoint?
    @State private var dragPreviewSize: CGSize?
    @State private var dragPreviewX: CGFloat?
    @State private var dropFrames: [String: CGRect] = [:]
    @State private var draggingPlace: DraggedPlace?
    @State private var placeDropIndex: Int?
    @State private var placeDragLocation: CGPoint?
    @State private var placePreviewFrame: CGRect?

    private struct DraggedPlace: Equatable {
        let payload: String
        let frameScope: String
        let index: Int
        let name: String
        let count: Int
    }

    private enum DraggedItem: Equatable {
        case recommendation(TimeTableRecommendation.ID)
        case row(TimeTableEditRow.ID, TimeTableEditRow.Source)
    }

    private enum DropTarget: Equatable {
        case row(String)
        case merge(String)
        case append
        case day(TripDay)
        case trash
    }

    @State private var activeDropTarget: DropTarget?

    private struct ConfirmedRecommendationGroup: Identifiable {
        let id: String
        let title: String
        let category: String
        let memberIDs: [String]
    }

    private var rows: [TimeTableEditRow] {
        store.rowsByDay[timeTableStore.selectedDay] ?? []
    }

    private var draggedRowID: TimeTableEditRow.ID? {
        guard case let .row(rowID, _) = dragging else { return nil }
        return rowID
    }

    private var isReorderingSchedule: Bool {
        draggedRowID != nil
    }

    private func availableRecommendationGroups(
        editState: TimeTableEditFeature.State
    ) -> [ConfirmedRecommendationGroup] {
        let placedGroupIDs = TimeTableFeature.State.placedRecommendationGroupIDs(in: editState)
        let orderedGroupIDs = timeTableStore.recommendations.reduce(into: [String]()) { result, item in
            guard !result.contains(item.groupID) else { return }
            result.append(item.groupID)
        }

        return orderedGroupIDs.compactMap { groupID in
            guard !placedGroupIDs.contains(groupID) else { return nil }
            let places = timeTableStore.recommendations.filter { $0.groupID == groupID }
            guard let first = places.first else { return nil }

            let categories = places.reduce(into: [String]()) { result, place in
                guard !result.contains(place.category) else { return }
                result.append(place.category)
            }
            let memberIDs = places
                .flatMap(\.memberIDs)
                .reduce(into: [String]()) { result, memberID in
                    guard !result.contains(memberID) else { return }
                    result.append(memberID)
                }

            return ConfirmedRecommendationGroup(
                id: groupID,
                title: places.count > 1
                    ? "\(first.placeName) 외 \(places.count - 1)곳"
                    : first.placeName,
                category: categories.joined(separator: " · "),
                memberIDs: memberIDs
            )
        }
    }

    var body: some View {
        ZStack {
            DDColor.surfaceDefault.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                navigationBar
                tripHeader
                dayPicker

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        recommendationSection
                        scheduleSection
                        if dragging != nil {
                            appendDropArea
                                .padding(.leading, 48)
                                .padding(.trailing, DDSpacing.large)
                        }
                        addPlaceButton
                            .padding(.leading, 48)
                            .padding(.trailing, DDSpacing.large)
                            .padding(.top, DDSpacing.medium)
                    }
                    .padding(.bottom, DDSpacing.xLarge)
                }
                .scrollIndicators(.hidden)
                .id(timeTableStore.selectedDay)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .coordinateSpace(name: "timeTableEditDrag")
        .overlay(alignment: .bottom) {
            if isDeletionOverlayPresented {
                deletionDropArea
                    .zIndex(1)
            }
        }
        .onPreferenceChange(TimeTableDropFramesKey.self) { dropFrames = $0 }
        .overlay {
            GeometryReader { proxy in
                insertionIndicatorsOverlay
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .allowsHitTesting(false)
        }
        .overlay {
            GeometryReader { proxy in
                ZStack {
                    if let dragging, let dragLocation {
                        dragPreview(dragging)
                            .position(
                                x: resolvedDragPreviewX(for: dragging, fallback: dragLocation.x),
                                y: dragLocation.y
                            )
                    }
                    if let draggingPlace, let placeDragLocation, let placePreviewFrame {
                        placeDragPreview(draggingPlace)
                            .frame(width: placePreviewFrame.width, height: placePreviewFrame.height)
                            .position(x: placePreviewFrame.midX, y: placeDragLocation.y)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
    }

    private var navigationBar: some View {
        DDNavigationHeader(onBack: { store.send(.backButtonTapped) }) {
            Spacer()

            Button("저장") { store.send(.saveButtonTapped) }
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.textOnPrimary)
                .frame(width: 64, height: 40)
                .background(DDColor.actionPrimary, in: Capsule())
                .buttonStyle(.plain)
                .disabled(store.isSaving)
                .opacity(store.isSaving ? 0.5 : 1)
        }
        .frame(height: 44)
        .padding(.trailing, DDSpacing.large)
    }

    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DDSpacing.small) {
                Text(timeTableStore.headerTitle)
                    .ddTypography(.title24)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DDColor.textPrimary)
            }
            .frame(height: 33, alignment: .leading)

            if let date = timeTableStore.tripDateText {
                Text(date)
                    .ddTypography(.body16)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(1)
                    .frame(height: 24, alignment: .leading)
            }

            // 조회 화면의 안내 문구 높이를 유지해 DAY 탭의 위치를 맞춘다.
            Color.clear.frame(height: 24)
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.bottom, 5)
    }

    private var dayPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DDSpacing.small) {
                ForEach(timeTableStore.availableDays) { day in
                    Button { timeTableStore.send(.daySelected(day)) } label: {
                        Text(day.rawValue)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.textPrimary)
                            .frame(width: 64, height: 40)
                            .background(
                                day == timeTableStore.selectedDay || activeDropTarget == .day(day)
                                    ? Color(red: 118 / 255, green: 118 / 255, blue: 118 / 255)
                                    : .clear
                            )
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().stroke(
                                    Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255),
                                    lineWidth: 1
                                )
                            }
                    }
                    .buttonStyle(.plain)
                    .background(dropFrame("day:\(day.rawValue)"))
                }
            }
            .padding(.horizontal, DDSpacing.large)
        }
        .scrollIndicators(.hidden)
        .frame(height: 42, alignment: .top)
        .padding(.top, DDSpacing.small)
    }

    private var recommendationSection: some View {
        WithViewStore(timeTableStore, observe: \.edit) { viewStore in
            VStack(alignment: .leading, spacing: 10) {
                Text("추천 그룹 추가하기")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.leading, DDSpacing.large)

                ScrollView(.horizontal) {
                    HStack(spacing: DDSpacing.large) {
                        ForEach(availableRecommendationGroups(editState: viewStore.state)) { group in
                            editCard(
                                title: group.title,
                                subtitle: group.category,
                                memberIDs: group.memberIDs,
                                width: 200,
                                drag: .recommendation(group.id)
                            )
                            .opacity(dragging == .recommendation(group.id) ? 0 : 1)
                        }
                    }
                    .padding(.horizontal, DDSpacing.large)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, DDSpacing.large)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: DDSpacing.large) {
            Text("여행 일정")
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.horizontal, DDSpacing.medium)

            LazyVStack(spacing: DDSpacing.large) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .top, spacing: 20) {
                        timelineMarker(
                            index: index,
                            count: rows.count,
                            rowHeight: editRowHeight(row)
                        )
                        rowCards(row)
                    }
                    .padding(.leading, DDSpacing.medium)
                    .padding(.trailing, DDSpacing.large)
                    .background(dropFrame("row:\(row.id)"))
                }
            }
        }
        .padding(.top, DDSpacing.large)
    }

    private func timelineMarker(index: Int, count: Int, rowHeight: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if index < count - 1 {
                Rectangle()
                    .fill(DDColor.textTertiary)
                    .frame(width: 5, height: rowHeight + DDSpacing.large)
                    .offset(y: 7)
            }
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 15, height: 15)
                .background(DDColor.actionPrimary, in: Circle())
        }
        .frame(width: 16, height: rowHeight, alignment: .top)
    }

    @ViewBuilder
    private func rowCards(_ row: TimeTableEditRow) -> some View {
        if row.sources.count > 1 {
            GeometryReader { geometry in
                let spacing = DDSpacing.large
                let cardWidth = row.sources.count <= 2
                    ? 200
                    : max(
                        112,
                        min(200, (geometry.size.width + spacing) * 2 / CGFloat(row.sources.count) - spacing)
                    )

                ScrollView(.horizontal) {
                    HStack(spacing: spacing) {
                        ForEach(row.sources, id: \.self) { source in
                            sourceCard(source, rowID: row.id, width: cardWidth)
                        }
                    }
                }
                .frame(width: geometry.size.width, alignment: .leading)
                .scrollIndicators(.hidden)
            }
            .frame(height: editRowHeight(row))
        } else if let source = row.sources.first {
            sourceCard(source, rowID: row.id, width: nil)
        }
    }

    @ViewBuilder
    private func sourceCard(_ source: TimeTableEditRow.Source, rowID: String, width: CGFloat?) -> some View {
        switch source {
        case let .schedule(id):
            if let schedule = store.draftPlacements.first(where: { $0.id == id }),
               let course = timeTableStore.coursesByID[schedule.courseID] {
                let dragItem = DraggedItem.row(rowID, source)
                editablePlaceCard(
                    title: course.title,
                    subtitle: course.categorySummary,
                    memberIDs: course.members.map(\.rawValue),
                    placeNames: course.placeNames,
                    width: width,
                    drag: dragItem,
                    placePayload: { index in "course:\(course.id):\(index)" }
                )
                    .opacity(dragging == dragItem ? 0.3 : 1)
                    .saturation(dragging == dragItem ? 0.25 : 1)
            }
        case let .recommendationGroup(id):
            let places = timeTableStore.recommendations.filter { $0.groupID == id }
            if let first = places.first {
                let dragItem = DraggedItem.row(rowID, source)
                editablePlaceCard(
                    title: places.count > 1 ? "\(first.placeName) 외 \(places.count - 1)곳" : first.placeName,
                    subtitle: places.categorySummary,
                    memberIDs: first.memberIDs,
                    placeNames: places.map(\.placeName),
                    width: width,
                    drag: dragItem,
                    placePayload: { index in "recommendation:\(id):\(index)" }
                )
                    .opacity(dragging == dragItem ? 0.3 : 1)
                    .saturation(dragging == dragItem ? 0.25 : 1)
            }
        }
    }

    private func editablePlaceCard(
        title: String,
        subtitle: String,
        memberIDs: [String],
        placeNames: [String],
        width: CGFloat?,
        drag: DraggedItem,
        placePayload: @escaping (Int) -> String
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DDSpacing.small) {
                VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
                    HStack(spacing: DDSpacing.xSmall) {
                        Text(title)
                            .ddTypography(.bodyEmphasis16)
                            .foregroundStyle(DDColor.textPrimary)
                            .lineLimit(1)
                        if shouldDisplayMemberDots(for: memberIDs) {
                            memberDots(memberIDs)
                        }
                    }

                    Text(subtitle)
                        .ddTypography(.labelEmphasis14)
                        .foregroundStyle(DDColor.actionPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
                dragHandle(drag)
            }
            .padding(.horizontal, DDSpacing.medium)
            .frame(height: 71)

            VStack(spacing: DDSpacing.small) {
                ForEach(Array(placeNames.enumerated()), id: \.offset) { index, placeName in
                    let place = DraggedPlace(
                        payload: placePayload(index),
                        frameScope: dragFrameID(drag),
                        index: index,
                        name: placeName,
                        count: placeNames.count
                    )
                    HStack(spacing: DDSpacing.medium) {
                        Text("\(index + 1)")
                            .ddTypography(.bodyEmphasis16)
                            .foregroundStyle(DDColor.actionPrimary)
                            .frame(width: 20)

                        Text(placeName)
                            .ddTypography(.bodyEmphasis16)
                            .foregroundStyle(DDColor.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        placeDragHandle(place)
                    }
                    .padding(.horizontal, DDSpacing.medium)
                    .frame(height: 44)
                    .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    .opacity(draggingPlace?.payload == place.payload ? 0.3 : 1)
                    .saturation(draggingPlace?.payload == place.payload ? 0.25 : 1)
                    .background(dropFrame("place:\(place.frameScope):\(index)"))
                }
            }
            .padding(.horizontal, DDSpacing.small)
            .padding(.top, DDSpacing.small)
            .padding(.bottom, 12)
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(DDColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.textTertiary, lineWidth: 1)
        }
        .background(dropFrame(dragFrameID(drag)))
    }

    private func placeDragHandle(_ place: DraggedPlace) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color(red: 222 / 255, green: 222 / 255, blue: 222 / 255))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .frame(width: 44, height: 44, alignment: .trailing)
        .contentShape(Rectangle())
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.3, maximumDistance: 12)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("timeTableEditDrag")))
                .onChanged { phase in
                    guard case .second(true, let drag) = phase else { return }
                    draggingPlace = place
                    if placePreviewFrame == nil {
                        placePreviewFrame = dropFrames["place:\(place.frameScope):\(place.index)"]
                    }
                    if let drag {
                        placeDragLocation = drag.location
                        updatePlaceDropTarget(at: drag.location)
                    }
                }
                .onEnded { phase in
                    if case .second(true, _?) = phase {
                        commitPlaceDrop()
                    }
                    finishPlaceDrag()
                }
        )
        .accessibilityLabel("장소 순서 변경")
    }

    private func movePlace(payload: String, toInsertionIndex insertionIndex: Int, count: Int) {
        let components = payload.split(separator: ":", maxSplits: 2).map(String.init)
        guard components.count == 3,
              let sourceIndex = Int(components[2]),
              (0..<count).contains(sourceIndex),
              (0...count).contains(insertionIndex),
              insertionIndex != sourceIndex,
              insertionIndex != sourceIndex + 1
        else { return }
        let destinationIndex = insertionIndex > sourceIndex
            ? insertionIndex - 1 : insertionIndex

        switch components[0] {
        case "course":
            guard let courseID = Int(components[1]) else { return }
            store.send(.coursePlaceMoved(
                courseID,
                sourceIndex: sourceIndex,
                beforeIndex: destinationIndex
            ))
        case "recommendation":
            store.send(.recommendationPlaceMoved(
                components[1],
                sourceIndex: sourceIndex,
                beforeIndex: destinationIndex
            ))
        default:
            return
        }
    }

    private func updatePlaceDropTarget(at location: CGPoint) {
        guard let draggingPlace else { return }
        placeDropIndex = nil

        for index in 0..<draggingPlace.count {
            guard let frame = dropFrames["place:\(draggingPlace.frameScope):\(index)"],
                  (frame.minX...frame.maxX).contains(location.x),
                  ((frame.minY - DDSpacing.small / 2)...(frame.maxY + DDSpacing.small / 2))
                    .contains(location.y)
            else { continue }

            let insertionIndex = location.y < frame.midY ? index : index + 1
            if insertionIndex != draggingPlace.index,
               insertionIndex != draggingPlace.index + 1 {
                placeDropIndex = insertionIndex
            }
            return
        }
    }

    private func commitPlaceDrop() {
        guard let draggingPlace, let placeDropIndex else { return }
        movePlace(
            payload: draggingPlace.payload,
            toInsertionIndex: placeDropIndex,
            count: draggingPlace.count
        )
    }

    private func finishPlaceDrag() {
        draggingPlace = nil
        placeDropIndex = nil
        placeDragLocation = nil
        placePreviewFrame = nil
    }

    private func placeDragPreview(_ place: DraggedPlace) -> some View {
        HStack(spacing: DDSpacing.medium) {
            Text("\(place.index + 1)")
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.actionPrimary)
                .frame(width: 20)
            Text(place.name)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            placeDragHandle(place)
        }
        .padding(.horizontal, DDSpacing.medium)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .scaleEffect(1.015)
        .shadow(color: .black.opacity(0.28), radius: 12, y: 7)
    }

    private func editRowHeight(_ row: TimeTableEditRow) -> CGFloat {
        let placeCount = row.sources.map { source -> Int in
            switch source {
            case let .schedule(scheduleID):
                guard let schedule = store.draftPlacements.first(where: { $0.id == scheduleID })
                else { return 0 }
                return timeTableStore.coursesByID[schedule.courseID]?.placeNames.count ?? 0
            case let .recommendationGroup(groupID):
                return timeTableStore.recommendations.filter { $0.groupID == groupID }.count
            }
        }.max() ?? 0
        guard placeCount > 0 else { return 71 }
        return 83 + CGFloat(placeCount) * 52
    }

    private func editCard(
        title: String,
        subtitle: String,
        memberIDs: [String],
        width: CGFloat?,
        drag: DraggedItem
    ) -> some View {
        HStack(spacing: DDSpacing.small) {
            VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
                HStack(spacing: DDSpacing.xSmall) {
                    Text(title)
                        .ddTypography(.bodyEmphasis16)
                        .foregroundStyle(DDColor.textPrimary)
                        .lineLimit(1)
                    if shouldDisplayMemberDots(for: memberIDs) {
                        memberDots(memberIDs)
                    }
                }
                Text(subtitle)
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(DDColor.actionPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            dragHandle(drag)
        }
        .padding(.horizontal, DDSpacing.medium)
        .frame(width: width, height: 71)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(DDColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.textTertiary, lineWidth: 1)
        }
        .background(dropFrame(dragFrameID(drag)))
    }

    private func memberDots(_ memberIDs: [String]) -> some View {
        HStack(spacing: -5) {
            ForEach(TripMember.allCases.filter { memberIDs.contains($0.rawValue) }) { member in
                Circle()
                    .fill(member.routeAccentColor)
                    .frame(width: 14, height: 14)
            }
        }
    }

    private func shouldDisplayMemberDots(for memberIDs: [String]) -> Bool {
        TimeTableCourse.kind(of: memberIDs, among: timeTableStore.tripMembers) == .separate
    }

    private func dragHandle(_ item: DraggedItem) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color(red: 222 / 255, green: 222 / 255, blue: 222 / 255))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .frame(width: 31.4, height: 22)
        .frame(width: 44, height: 44, alignment: .trailing)
        .contentShape(Rectangle())
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.3, maximumDistance: 12)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("timeTableEditDrag")))
                .onChanged { phase in
                    switch phase {
                    case .second(true, let drag):
                        dragging = item
                        if dragPreviewSize == nil,
                           let frame = dropFrames[dragFrameID(item)] {
                            dragPreviewSize = frame.size
                            if case .row = item {
                                dragPreviewX = frame.midX
                            }
                        }
                        if case .row = item {
                            isDeletionOverlayPresented = true
                        }
                        if let drag {
                            dragLocation = drag.location
                            updateDropTarget(at: drag.location)
                        }
                    default:
                        break
                    }
                }
                .onEnded { phase in
                    if case .second(true, _?) = phase {
                        commitDrop()
                    }
                    finishDrag()
                }
        )
        .accessibilityLabel("드래그하여 일정 이동")
    }

    private var addPlaceButton: some View {
        Button { store.send(.addScheduleButtonTapped) } label: {
            Text("+ 장소 추가하기")
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.leading, DDSpacing.xLarge)
                .frame(maxWidth: .infinity, minHeight: 71, alignment: .leading)
                .background(DDColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(DDColor.actionPrimary, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var appendDropArea: some View {
        Color.clear
        .frame(maxWidth: .infinity)
        .frame(height: DDSpacing.large)
        .contentShape(Rectangle())
        .background(dropFrame("append"))
    }

    private var insertionIndicator: some View {
        Capsule()
            .fill(DDColor.actionPrimary)
            .frame(height: 2)
    }

    private var parallelInsertionIndicator: some View {
        Capsule()
            .fill(DDColor.actionPrimary)
            .frame(width: 2)
    }

    private func insertionIndicatorWidth(for frame: CGRect) -> CGFloat {
        max(0, frame.width - 48 - DDSpacing.large)
    }

    @ViewBuilder
    private var insertionIndicatorsOverlay: some View {
        if let draggingPlace {
            if let placeDropIndex,
               let frame = placeInsertionFrame(for: draggingPlace, at: placeDropIndex) {
                insertionIndicator
                    .frame(width: max(0, frame.width - DDSpacing.medium))
                    .position(
                        x: frame.midX,
                        y: placeDropIndex == draggingPlace.count
                            ? frame.maxY + DDSpacing.small / 2
                            : frame.minY - DDSpacing.small / 2
                    )
                    .zIndex(2)
                    .allowsHitTesting(false)
            }
        } else if let targetedRowID,
           targetedRowID != draggedRowID,
           let frame = dropFrames["row:\(targetedRowID)"] {
            insertionIndicator
                .frame(width: insertionIndicatorWidth(for: frame))
                .position(
                    x: frame.minX + 48 + insertionIndicatorWidth(for: frame) / 2,
                    y: frame.minY - DDSpacing.small
                )
                .zIndex(2)
                .allowsHitTesting(false)
        } else if isAppendTargeted {
            if let lastRow = rows.last,
               let frame = dropFrames["row:\(lastRow.id)"] {
                insertionIndicator
                    .frame(width: insertionIndicatorWidth(for: frame))
                    .position(
                        x: frame.minX + 48 + insertionIndicatorWidth(for: frame) / 2,
                        y: frame.maxY + DDSpacing.small
                    )
                    .zIndex(2)
                    .allowsHitTesting(false)
            } else if let frame = dropFrames["append"] {
                insertionIndicator
                    .frame(width: frame.width)
                    .position(x: frame.midX, y: frame.midY)
                    .zIndex(2)
                    .allowsHitTesting(false)
            }
        } else if case let .merge(rowID) = activeDropTarget,
                  canMergeDraggedItem(into: rowID),
                  let targetRow = rows.first(where: { $0.id == rowID }),
                  let lastSource = targetRow.sources.last,
                  let frame = dropFrames[dragFrameID(.row(rowID, lastSource))] {
            parallelInsertionIndicator
                .frame(height: max(0, frame.height - DDSpacing.large))
                .position(x: frame.maxX + DDSpacing.small, y: frame.midY)
                .zIndex(2)
                .allowsHitTesting(false)
        }
    }

    private func placeInsertionFrame(for place: DraggedPlace, at index: Int) -> CGRect? {
        let frameIndex = index == place.count ? index - 1 : index
        return dropFrames["place:\(place.frameScope):\(frameIndex)"]
    }

    private func canMergeDraggedItem(into targetRowID: TimeTableEditRow.ID) -> Bool {
        guard let dragging,
              let targetRow = rows.first(where: { $0.id == targetRowID }),
              let targetMembers = memberIDs(for: targetRow),
              !targetMembers.isEmpty else { return false }

        switch dragging {
        case let .recommendation(groupID):
            let sourceMembers = Set(
                timeTableStore.recommendations
                    .first(where: { $0.groupID == groupID })?
                    .memberIDs ?? []
            )
            return !sourceMembers.isEmpty && sourceMembers.isDisjoint(with: targetMembers)

        case let .row(sourceRowID, source):
            guard sourceRowID != targetRowID,
                  let sourceMembers = memberIDs(for: source),
                  !sourceMembers.isEmpty else { return false }
            return sourceMembers.isDisjoint(with: targetMembers)
        }
    }

    private func memberIDs(for row: TimeTableEditRow) -> Set<String>? {
        var members: Set<String> = []
        for source in row.sources {
            guard let sourceMembers = memberIDs(for: source),
                  !sourceMembers.isEmpty,
                  members.isDisjoint(with: sourceMembers) else { return nil }
            members.formUnion(sourceMembers)
        }
        return members
    }

    private func memberIDs(for source: TimeTableEditRow.Source) -> Set<String>? {
        switch source {
        case let .schedule(scheduleID):
            guard let schedule = store.draftPlacements.first(where: { $0.id == scheduleID }),
                  let course = timeTableStore.coursesByID[schedule.courseID] else { return nil }
            return Set(course.members.map(\.rawValue))

        case let .recommendationGroup(groupID):
            guard let recommendation = timeTableStore.recommendations.first(where: {
                $0.groupID == groupID
            }) else { return nil }
            return Set(recommendation.memberIDs)
        }
    }

    private var deletionDropArea: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(DDColor.actionPrimary)
                .padding(.bottom, 25)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 246)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.black.opacity(0.8), location: 0.673),
                    .init(color: Color.black.opacity(0.8), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(dropFrame("trash"))
        .allowsHitTesting(false)
    }

    private func dropFrame(_ id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: TimeTableDropFramesKey.self,
                value: [id: proxy.frame(in: .named("timeTableEditDrag"))]
            )
        }
    }

    private func updateDropTarget(at location: CGPoint) {
        let target: DropTarget?
        if let insertionTarget = insertionTarget(at: location) {
            target = insertionTarget
        } else if case .row = dragging,
                  let day = timeTableStore.availableDays.first(where: {
                      $0 != timeTableStore.selectedDay &&
                      dropFrames["day:\($0.rawValue)"]?.contains(location) == true
                  }) {
            target = .day(day)
        } else if case .row = dragging, dropFrames["trash"]?.contains(location) == true {
            target = .trash
        } else if let row = rows.first(where: { dropFrames["row:\($0.id)"]?.contains(location) == true }),
           let frame = dropFrames["row:\(row.id)"] {
            switch dragging {
            case .recommendation:
                target = .merge(row.id)
            case .row:
                target = location.x >= frame.midX && canMergeDraggedItem(into: row.id)
                    ? .merge(row.id)
                    : .row(row.id)
            case nil:
                target = .row(row.id)
            }
        } else if dropFrames["append"]?.contains(location) == true {
            target = .append
        } else {
            target = nil
        }
        activeDropTarget = target
        switch target {
        case let .row(id):
            targetedRowID = id
        case .merge:
            targetedRowID = nil
        case .append, .day, .trash, nil:
            targetedRowID = nil
        }
        isAppendTargeted = target == .append
    }

    private func insertionTarget(at location: CGPoint) -> DropTarget? {
        for row in rows {
            guard let frame = dropFrames["row:\(row.id)"] else { continue }

            let horizontalRange = (frame.minX + 48)...(frame.maxX - DDSpacing.large)
            let verticalRange = (frame.minY - DDSpacing.large)...frame.minY
            if horizontalRange.contains(location.x), verticalRange.contains(location.y) {
                return .row(row.id)
            }
        }

        guard let lastRow = rows.last,
              let lastFrame = dropFrames["row:\(lastRow.id)"] else { return nil }
        let horizontalRange = (lastFrame.minX + 48)...(lastFrame.maxX - DDSpacing.large)
        let verticalRange = lastFrame.maxY...(lastFrame.maxY + DDSpacing.large)
        return horizontalRange.contains(location.x) && verticalRange.contains(location.y)
            ? .append
            : nil
    }

    private func commitDrop() {
        switch activeDropTarget {
        case let .row(id): _ = drop(before: id)
        case let .merge(id): _ = merge(into: id)
        case .append: _ = drop(before: nil)
        case let .day(day):
            if case let .row(rowID, source) = dragging {
                store.send(.rowMovedToDay(rowID, source: source, day: day))
            }
        case .trash:
            if case let .row(rowID, source) = dragging {
                store.send(.deletionRequested(timeTableStore.selectedDay, rowID: rowID, source: source))
            }
        case nil: break
        }
    }

    private func finishDrag() {
        dragging = nil
        isDeletionOverlayPresented = false
        dragLocation = nil
        dragPreviewSize = nil
        dragPreviewX = nil
        activeDropTarget = nil
        targetedRowID = nil
        isAppendTargeted = false
    }

    @ViewBuilder
    private func dragPreview(_ item: DraggedItem) -> some View {
        Group {
            switch item {
            case let .recommendation(id):
                let places = timeTableStore.recommendations.filter { $0.groupID == id }
                if let first = places.first {
                    editCard(title: places.count > 1 ? "\(first.placeName) 외 \(places.count - 1)곳" : first.placeName,
                             subtitle: places.categorySummary, memberIDs: first.memberIDs,
                             width: 200, drag: item)
                }
            case let .row(_, source):
                switch source {
                case let .schedule(scheduleID):
                    if let schedule = store.draftPlacements.first(where: { $0.id == scheduleID }),
                       let course = timeTableStore.coursesByID[schedule.courseID] {
                        editCard(title: course.title, subtitle: course.categorySummary,
                                 memberIDs: course.members.map(\.rawValue),
                                 width: dragPreviewSize?.width ?? 200, drag: item)
                    }
                case let .recommendationGroup(groupID):
                    let places = timeTableStore.recommendations.filter { $0.groupID == groupID }
                    if let first = places.first {
                        editCard(title: places.count > 1 ? "\(first.placeName) 외 \(places.count - 1)곳" : first.placeName,
                                 subtitle: places.categorySummary, memberIDs: first.memberIDs,
                                 width: dragPreviewSize?.width ?? 200, drag: item)
                    }
                }
            }
        }
        .scaleEffect(isReorderingSchedule ? 1.015 : 1)
        .shadow(
            color: .black.opacity(isReorderingSchedule ? 0.28 : 0),
            radius: isReorderingSchedule ? 12 : 0,
            y: isReorderingSchedule ? 7 : 0
        )
    }

    private func dragFrameID(_ item: DraggedItem) -> String {
        switch item {
        case let .recommendation(id):
            return "card:recommendation:\(id)"
        case let .row(rowID, source):
            switch source {
            case let .schedule(id):
                return "card:row:\(rowID):schedule:\(id)"
            case let .recommendationGroup(id):
                return "card:row:\(rowID):recommendation:\(id)"
            }
        }
    }

    private func resolvedDragPreviewX(for item: DraggedItem, fallback: CGFloat) -> CGFloat {
        guard case .row = item else { return fallback }
        return dragPreviewX ?? fallback
    }

    private func drop(before targetID: String?) -> Bool {
        guard let dragging else { return false }
        switch dragging {
        case let .recommendation(id):
            store.send(.recommendationDropped(id, before: targetID))
        case let .row(id, source):
            store.send(.scheduleRowMoved(id, source: source, before: targetID))
        }
        self.dragging = nil
        return true
    }

    private func merge(into rowID: String) -> Bool {
        guard let dragging else { return false }
        switch dragging {
        case let .recommendation(id):
            store.send(.recommendationMerged(id, into: rowID))
        case let .row(id, source): store.send(.rowMerged(id, source: source, into: rowID))
        }
        self.dragging = nil
        return true
    }
}

#if DEBUG
#Preview("편집 · 추천 그룹 목업") {
    TimeTableView(store: Store(initialState: TimeTableFeature.debugEditPreviewState) {
        TimeTableFeature()
    })
}
#endif
