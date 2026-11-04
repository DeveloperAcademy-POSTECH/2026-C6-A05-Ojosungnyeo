//
//  TimeTableView.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture
import SwiftUI

struct TimeTableView: View {
    let store: StoreOf<TimeTableFeature>

    var body: some View {
        Group {
            if store.isEditing {
                TimeTableEditView(
                    timeTableStore: store,
                    store: store.scope(state: \.edit, action: \.edit)
                )
            } else {
                TimeTableReadOnlyContent(
                    store: store,
                    onBack: { store.send(.backButtonTapped) },
                    onEdit: { store.send(.editButtonTapped) }
                )
            }
        }
        .onAppear { store.send(.validateSelectedDay) }
        .onChange(of: store.availableDays) { _, _ in
            store.send(.validateSelectedDay)
        }
    }
}

private struct TimeTableReadOnlyContent: View {
    let store: StoreOf<TimeTableFeature>
    let onBack: () -> Void
    let onEdit: () -> Void

    private var scheduledCourses: [(schedule: TimeTableSchedule, course: TimeTableCourse)] {
        store.placements.enumerated()
            .filter {
                $0.element.day == store.selectedDay &&
                store.dayOfMonthByDay[$0.element.day] != nil
            }
            .compactMap { index, schedule in
                store.coursesByID[schedule.courseID].map { (index, schedule, $0) }
            }
            .sorted {
                let left = $0.1.timing.startMinuteOfDay
                let right = $1.1.timing.startMinuteOfDay
                return left == right ? $0.0 < $1.0 : left < right
            }
            .map { ($0.1, $0.2) }
    }

    var body: some View {
        ZStack {
            DDColor.surfaceDefault.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                navigationBar
                tripHeader
                dayPicker

                ScrollView {
                    scheduleSection
                        .padding(.bottom, DDSpacing.xLarge)
                }
                .scrollIndicators(.hidden)
                .id(store.selectedDay)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, DDSpacing.large)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var navigationBar: some View {
        HStack {
            Button(action: onBack) {
                Image("DDTimeTableBack")
                    .resizable()
                    .frame(width: 20, height: 40)
                    .frame(width: 44, height: 40, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button("편집", action: onEdit)
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.textPrimary)
                .frame(width: 64, height: 40)
                .background(DDColor.surfaceControl)
                .clipShape(.capsule)
                .buttonStyle(.plain)
        }
        .frame(height: 40)
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, 7)
    }

    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DDSpacing.small) {
                Text("여행 일정을 살펴보게따")
                    .ddTypography(.title24)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DDColor.textPrimary)
            }
            .frame(height: 33, alignment: .leading)

            if let tripDateText = store.tripDateText {
                Text(tripDateText)
                    .ddTypography(.body16)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(1)
                    .frame(height: 24, alignment: .leading)
            }

            Text("추천 그룹 추가는 편집 뷰에서 가능해요.")
                .ddTypography(.body16)
                .foregroundStyle(DDColor.textSecondary)
                .lineLimit(1)
                .frame(height: 24, alignment: .leading)
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.bottom, 5)
    }

    private var dayPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DDSpacing.small) {
                ForEach(store.availableDays) { day in
                    Button {
                        store.send(.daySelected(day))
                    } label: {
                        Text(day.rawValue)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.textPrimary)
                            .frame(width: 64, height: 40)
                            .background(
                                day == store.selectedDay
                                    ? Color(red: 118 / 255, green: 118 / 255, blue: 118 / 255)
                                    : .clear
                            )
                            .clipShape(.capsule)
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

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: DDSpacing.large) {
            Text("여행 일정")
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.horizontal, DDSpacing.medium)

            LazyVStack(spacing: DDSpacing.large) {
                #if DEBUG
                if store.isLocalPreview, store.recommendationTripID == nil,
                   let savedRows = store.savedPreviewRowsByDay?[store.selectedDay] {
                    ForEach(Array(savedRows.enumerated()), id: \.element.id) { index, row in
                        HStack(alignment: .top, spacing: 20) {
                            timelineMarker(number: index + 1, isLast: index == savedRows.count - 1)
                            savedPreviewRow(row)
                        }
                        .padding(.leading, DDSpacing.medium)
                        .padding(.trailing, DDSpacing.large)
                    }
                } else {
                    originalScheduleRows
                }
                #else
                originalScheduleRows
                #endif
            }
        }
        .padding(.top, DDSpacing.xLarge)
    }

    private var originalScheduleRows: some View {
        ForEach(Array(scheduledCourses.enumerated()), id: \.element.schedule.id) { index, item in
            HStack(alignment: .top, spacing: 20) {
                timelineMarker(number: index + 1, isLast: index == scheduledCourses.count - 1)
                scheduleCard(item.course)
            }
            .padding(.leading, DDSpacing.medium)
            .padding(.trailing, DDSpacing.large)
        }
    }

    #if DEBUG
    @ViewBuilder
    private func savedPreviewRow(_ row: TimeTableEditRow) -> some View {
        if row.sources.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: DDSpacing.small) {
                    ForEach(Array(row.sources.enumerated()), id: \.offset) { item in
                        savedPreviewCard(item.element).frame(width: 200)
                    }
                }
            }
            .scrollIndicators(.hidden)
        } else if let source = row.sources.first {
            savedPreviewCard(source)
        }
    }

    @ViewBuilder
    private func savedPreviewCard(_ source: TimeTableEditRow.Source) -> some View {
        switch source {
        case let .schedule(id):
            if let schedule = store.savedPreviewPlacements?.first(where: { $0.id == id }),
               let course = store.coursesByID[schedule.courseID] {
                scheduleCard(course)
            }
        case let .recommendationGroup(id):
            let places = store.recommendations.filter { $0.groupID == id }
            if let first = places.first {
                VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
                    HStack(spacing: DDSpacing.xSmall) {
                        Text(places.count > 1 ? "\(first.placeName) 외 \(places.count - 1)곳" : first.placeName)
                            .ddTypography(.bodyEmphasis16)
                            .foregroundStyle(DDColor.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: -5) {
                            ForEach(TripMember.allCases.filter { first.memberIDs.contains($0.rawValue) }) { member in
                                Circle().fill(member.routeAccentColor).frame(width: 14, height: 14)
                            }
                        }
                    }
                    Text(first.category)
                        .ddTypography(.labelEmphasis14)
                        .foregroundStyle(DDColor.actionPrimary)
                }
                .padding(.horizontal, DDSpacing.xLarge)
                .frame(maxWidth: .infinity, minHeight: 71, alignment: .leading)
                .background(DDColor.surfaceElevated)
                .clipShape(.rect(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(DDColor.textTertiary, lineWidth: 1) }
            }
        }
    }
    #endif

    private func timelineMarker(number: Int, isLast: Bool) -> some View {
        ZStack(alignment: .top) {
            if !isLast {
                Rectangle()
                    .fill(DDColor.textTertiary)
                    .frame(width: 5, height: 87)
                    .offset(y: 7)
            }

            Text("\(number)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 15, height: 15)
                .background(DDColor.actionPrimary, in: Circle())
        }
        .frame(width: 16, height: 71, alignment: .top)
    }

    private func scheduleCard(_ course: TimeTableCourse) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
            HStack(spacing: DDSpacing.xSmall) {
                Text(course.title)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                if course.kind(among: store.tripMembers) == .separate {
                    HStack(spacing: -5) {
                        ForEach(TripMember.allCases.filter(course.members.contains)) { member in
                            Circle()
                                .fill(member.routeAccentColor)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }

            Text(course.placesSummary)
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.actionPrimary)
                .lineLimit(1)
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
}

struct TimeTableContent: View {
    let store: StoreOf<TimeTableFeature>
    let onBack: () -> Void
    var onEdit: (() -> Void)?
    var onSave: (() -> Void)?
    var onAddSchedule: (() -> Void)?
    var onScheduleTapped: ((TimeTableSchedule.ID) -> Void)?
    var onGroupAdd: ((TimeTableGroup.ID) -> Void)?
    var groups: [TimeTableGroup]?

    var body: some View {
        ZStack {
            DDColor.surfaceDefault
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    navigationBar
                    tripHeader
                    dayPicker
                    if let groups, !groups.isEmpty {
                        groupSection(groups)
                    }
                    scheduleSection
                }
                .padding(.bottom, DDSpacing.large)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private var navigationBar: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            if let onEdit {
                Button("편집") {
                    onEdit()
                }
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.textPrimary)
                .frame(width: 64, height: 40)
                .background(DDColor.surfaceControl)
                .clipShape(.capsule)
                .buttonStyle(.plain)
            }

            if let onSave {
                Button("저장") {
                    onSave()
                }
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.textOnPrimary)
                .frame(width: 64, height: 40)
                .background(DDColor.actionPrimary)
                .clipShape(.capsule)
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, DDSpacing.small)
        .padding(.trailing, DDSpacing.large)
    }

    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DDSpacing.small) {
                Text("도쿄 여행을 살펴보게따")
                    .ddTypography(.title24)
                    .foregroundStyle(DDColor.textPrimary)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DDColor.textPrimary)
            }

            Text("11월 22일 ~ 25일 · 3박 4일")
                .ddTypography(.body16)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(.horizontal, DDSpacing.large)
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
                            .background(
                                day == store.selectedDay
                                    ? DDColor.surfaceControl
                                    : Color.clear
                            )
                            .clipShape(.capsule)
                            .overlay {
                                Capsule()
                                    .stroke(DDColor.borderDefault, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DDSpacing.large)
        }
        .scrollIndicators(.hidden)
        .padding(.top, DDSpacing.small)
    }

    private func groupSection(_ groups: [TimeTableGroup]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DDSpacing.medium) {
                ForEach(groups) { group in
                    TimeTableGroupCard(
                        group: group,
                        participantSummary: group.participantSummary(in: store.coursesByID),
                        onAdd: { onGroupAdd?(group.id) }
                    )
                }
            }
            .padding(.horizontal, DDSpacing.large)
        }
        .padding(.top, 36)
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: DDSpacing.small) {
            sectionTitle("전체 여행 일정")

            LazyVStack(spacing: 12) {
                ForEach(timelineRows) { row in
                    if row.isCompact {
                        compactScheduleRow(row.schedules)
                    } else if let schedule = row.schedules.first {
                        scheduleRow(schedule)
                    }
                }

                if let onAddSchedule {
                    HStack(alignment: .top, spacing: 20) {
                        timelineMarker(height: 126, showsLine: false)

                        Button(action: onAddSchedule) {
                            Text("+ 일정 추가")
                                .ddTypography(.body16)
                                .foregroundStyle(DDColor.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 126)
                                .background(DDColor.surfaceElevated)
                                .clipShape(.rect(cornerRadius: 20))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            DDColor.textTertiary,
                                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DDSpacing.large)
                }
            }
        }
        .padding(.top, groups?.isEmpty == false ? 14 : 18)
        .animation(.easeInOut(duration: 0.2), value: store.selectedDay)
    }

    private var timelineRows: [TimelineRow] {
        let originalSchedules = store.placements.filter {
            $0.day == store.selectedDay &&
            store.coursesByID[$0.courseID] != nil &&
            store.dayOfMonthByDay[$0.day] != nil
        }
        var rows: [TimelineRow] = []
        var seenBranchGroups: Set<Int> = []

        for schedule in originalSchedules {
            if let groupID = schedule.branchGroupID {
                guard seenBranchGroups.insert(groupID).inserted else { continue }
                rows.append(TimelineRow(
                    id: "branch-\(groupID)",
                    schedules: originalSchedules.filter { $0.branchGroupID == groupID },
                    isCompact: true
                ))
            } else {
                rows.append(TimelineRow(id: "schedule-\(schedule.id)", schedules: [schedule], isCompact: false))
            }
        }

        return rows.enumerated().sorted {
            let lhsMinute = $0.element.schedules.map(\.timing.startMinuteOfDay).min() ?? 0
            let rhsMinute = $1.element.schedules.map(\.timing.startMinuteOfDay).min() ?? 0
            return lhsMinute == rhsMinute ? $0.offset < $1.offset : lhsMinute < rhsMinute
        }.map(\.element)
    }

    private func compactScheduleRow(_ schedules: [TimeTableSchedule]) -> some View {
        HStack(alignment: .top, spacing: 20) {
            timelineMarker(height: 126, showsLine: true)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DDSpacing.small) {
                    ForEach(schedules) { schedule in
                        if let course = store.coursesByID[schedule.courseID],
                           let dayOfMonth = store.dayOfMonthByDay[schedule.day] {
                            TimeTableScheduleCard(
                                schedule: schedule,
                                course: course,
                                dayOfMonth: dayOfMonth,
                                tripMembers: store.tripMembers
                            ) {
                                scheduleTapped(schedule.id)
                            }
                            .frame(width: 205)
                        }
                    }
                }
                .padding(.trailing, DDSpacing.large)
            }
        }
        .padding(.leading, DDSpacing.large)
    }

    private func scheduleRow(_ schedule: TimeTableSchedule) -> some View {
        HStack(alignment: .top, spacing: 20) {
            timelineMarker(height: 126, showsLine: true)

            if let course = store.coursesByID[schedule.courseID],
               let dayOfMonth = store.dayOfMonthByDay[schedule.day] {
                TimeTableScheduleCard(
                    schedule: schedule,
                    course: course,
                    dayOfMonth: dayOfMonth,
                    tripMembers: store.tripMembers
                ) {
                    scheduleTapped(schedule.id)
                }
            }
        }
        .padding(.horizontal, DDSpacing.large)
    }

    private func scheduleTapped(_ id: TimeTableSchedule.ID) {
        if let onScheduleTapped {
            onScheduleTapped(id)
        } else {
            store.send(.scheduleTapped(id))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .ddTypography(.bodyEmphasis16)
            .foregroundStyle(DDColor.textPrimary)
            .padding(.horizontal, DDSpacing.large)
    }

    private func timelineMarker(height: CGFloat, showsLine: Bool) -> some View {
        ZStack(alignment: .top) {
            if showsLine {
                Rectangle()
                    .fill(DDColor.textTertiary)
                    .frame(width: 5, height: height + 12)
                    .offset(y: 7)
            }

            Circle()
                .fill(DDColor.actionPrimary)
                .frame(width: 15, height: 15)
        }
        .frame(width: 13, height: height, alignment: .top)
    }
}

private struct TimelineRow: Identifiable {
    let id: String
    let schedules: [TimeTableSchedule]
    let isCompact: Bool
}

#Preview {
    TimeTableView(
        store: Store(initialState: TimeTableFeature.State()) {
            TimeTableFeature()
        }
    )
}
