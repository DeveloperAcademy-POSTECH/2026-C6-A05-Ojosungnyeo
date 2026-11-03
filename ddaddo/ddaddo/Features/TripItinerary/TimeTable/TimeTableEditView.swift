import ComposableArchitecture
import SwiftUI

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
    }
}

private struct TimeTableEditContent: View {
    let timeTableStore: StoreOf<TimeTableFeature>
    let store: StoreOf<TimeTableEditFeature>

    @State private var dragging: DraggedItem?
    @State private var targetedRowID: String?
    @State private var isAppendTargeted = false

    private enum DraggedItem: Equatable {
        case recommendation(TimeTableRecommendation.ID)
        case row(TimeTableEditRow.ID)
    }

    private var rows: [TimeTableEditRow] {
        store.rowsByDay[timeTableStore.selectedDay] ?? []
    }

    private var availableRecommendations: [TimeTableRecommendation] {
        let placedIDs = Set(store.rowsByDay.values.flatMap { $0 }.compactMap { row -> String? in
            if case let .recommendation(id) = row.source { return id }
            return nil
        })
        return timeTableStore.recommendations.filter { !placedIDs.contains($0.id) }
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
        .preferredColorScheme(.dark)
    }

    private var navigationBar: some View {
        HStack {
            Button { store.send(.backButtonTapped) } label: {
                Image("DDTimeTableBack")
                    .resizable()
                    .frame(width: 20, height: 40)
                    .frame(width: 44, height: 40, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button("저장") { store.send(.saveButtonTapped) }
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.textOnPrimary)
                .frame(width: 64, height: 40)
                .background(DDColor.actionPrimary, in: Capsule())
                .buttonStyle(.plain)
        }
        .frame(height: 40)
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, 7)
    }

    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DDSpacing.small) {
                Text(timeTableStore.tripTitle ?? "여행 일정을 살펴보게따")
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
                ForEach(TripDay.allCases) { day in
                    Button { timeTableStore.send(.daySelected(day)) } label: {
                        Text(day.rawValue)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.textPrimary)
                            .frame(width: 64, height: 40)
                            .background(
                                day == timeTableStore.selectedDay
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
                }
            }
            .padding(.horizontal, DDSpacing.large)
        }
        .scrollIndicators(.hidden)
        .frame(height: 42, alignment: .top)
        .padding(.top, DDSpacing.small)
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("추천 그룹 추가하기")
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.leading, DDSpacing.large)

            ScrollView(.horizontal) {
                HStack(spacing: DDSpacing.large) {
                    ForEach(availableRecommendations) { recommendation in
                        editCard(
                            title: recommendation.placeName,
                            subtitle: recommendation.category,
                            memberIDs: recommendation.memberIDs,
                            width: 200,
                            drag: .recommendation(recommendation.id)
                        )
                    }
                }
                .padding(.horizontal, DDSpacing.large)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, DDSpacing.large)
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
                        timelineMarker(index: index, count: rows.count)
                        rowCards(row)
                    }
                    .padding(.leading, DDSpacing.medium)
                    .padding(.trailing, DDSpacing.large)
                    .background(targetedRowID == row.id ? DDColor.actionPrimary.opacity(0.12) : .clear)
                    .onDrop(of: ["public.text"], isTargeted: Binding(
                        get: { targetedRowID == row.id },
                        set: { targetedRowID = $0 ? row.id : nil }
                    )) { _ in
                        drop(before: row.id)
                    }
                }
            }
        }
        .padding(.top, DDSpacing.large)
    }

    private func timelineMarker(index: Int, count: Int) -> some View {
        ZStack(alignment: .top) {
            if index < count - 1 {
                Rectangle()
                    .fill(DDColor.textTertiary)
                    .frame(width: 5, height: 87)
                    .offset(y: 7)
            }
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 15, height: 15)
                .background(DDColor.actionPrimary, in: Circle())
        }
        .frame(width: 16, height: 71, alignment: .top)
    }

    @ViewBuilder
    private func rowCards(_ row: TimeTableEditRow) -> some View {
        switch row.source {
        case let .recommendation(id):
            if let item = timeTableStore.recommendations.first(where: { $0.id == id }) {
                editCard(title: item.placeName, subtitle: item.category,
                         memberIDs: item.memberIDs, width: nil, drag: .row(row.id))
            }
        case let .schedules(ids):
            let schedules = ids.compactMap { id in
                timeTableStore.placements.first(where: { $0.id == id })
            }
            if ids.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: DDSpacing.large) {
                        ForEach(schedules) { schedule in
                            if let course = timeTableStore.coursesByID[schedule.courseID] {
                                editCard(title: course.title, subtitle: course.placesSummary,
                                         memberIDs: course.members.map(\.rawValue),
                                         width: 200, drag: .row(row.id))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else if let schedule = schedules.first,
                      let course = timeTableStore.coursesByID[schedule.courseID] {
                editCard(title: course.title, subtitle: course.placesSummary,
                         memberIDs: course.members.map(\.rawValue),
                         width: nil, drag: .row(row.id))
            }
        }
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
                    memberDots(memberIDs)
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
        .onDrag {
            dragging = item
            return NSItemProvider(object: NSString(string: "time-table-edit"))
        }
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
        .background(isAppendTargeted ? DDColor.actionPrimary.opacity(0.12) : .clear)
        .onDrop(of: ["public.text"], isTargeted: $isAppendTargeted) { _ in
            drop(before: nil)
        }
    }

    private func drop(before targetID: String?) -> Bool {
        guard let dragging else { return false }
        switch dragging {
        case let .recommendation(id):
            store.send(.recommendationDropped(id, before: targetID))
        case let .row(id):
            store.send(.scheduleRowMoved(id, before: targetID))
        }
        self.dragging = nil
        return true
    }
}

#if DEBUG
#Preview("편집 · 추천 그룹 목업") {
    let timeTableStore = Store(initialState: TimeTableFeature.debugEditPreviewState) {
        TimeTableFeature()
    }
    TimeTableEditView(
        timeTableStore: timeTableStore,
        store: timeTableStore.scope(state: \.edit, action: \.edit)
    )
}
#endif
