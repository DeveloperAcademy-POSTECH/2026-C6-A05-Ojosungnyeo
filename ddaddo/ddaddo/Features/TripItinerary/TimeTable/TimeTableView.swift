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
        if store.isEditing {
            TimeTableEditView(
                timeTableStore: store,
                store: store.scope(state: \.edit, action: \.edit)
            )
        } else {
            TimeTableContent(
                store: store,
                onBack: { store.send(.backButtonTapped) },
                onEdit: { store.send(.editButtonTapped) }
            )
        }
    }
}

struct TimeTableContent: View {
    let store: StoreOf<TimeTableFeature>
    let onBack: () -> Void
    var onEdit: (() -> Void)?
    var onSave: (() -> Void)?
    var onAddSchedule: (() -> Void)?
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
                    if let groups {
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
                    TimeTableGroupCard(group: group)
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
                if !store.schedules.isEmpty {
                    compactScheduleRow(
                        branchSchedules.isEmpty
                            ? Array(store.schedules.prefix(2))
                            : branchSchedules
                    )
                }

                ForEach(regularSchedules) { schedule in
                    scheduleRow(schedule)
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
        .padding(.top, groups == nil ? 18 : 14)
        .animation(.easeInOut(duration: 0.2), value: store.selectedDay)
    }

    private var branchSchedules: [TimeTableSchedule] {
        store.schedules.filter { $0.branchGroupID != nil }
    }

    private var regularSchedules: [TimeTableSchedule] {
        branchSchedules.isEmpty
            ? store.schedules
            : store.schedules.filter { $0.branchGroupID == nil }
    }

    private func compactScheduleRow(_ schedules: [TimeTableSchedule]) -> some View {
        HStack(alignment: .top, spacing: 20) {
            timelineMarker(height: 126, showsLine: true)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DDSpacing.small) {
                    ForEach(schedules) { schedule in
                        TimeTableScheduleCard(schedule: schedule, tripMembers: store.tripMembers) {
                            store.send(.scheduleTapped(schedule.id))
                        }
                        .frame(width: 205)
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

            TimeTableScheduleCard(schedule: schedule, tripMembers: store.tripMembers) {
                store.send(.scheduleTapped(schedule.id))
            }
        }
        .padding(.horizontal, DDSpacing.large)
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

#Preview {
    TimeTableView(
        store: Store(initialState: TimeTableFeature.State()) {
            TimeTableFeature()
        }
    )
}
