//
//  TripDatePickerView.swift
//  ddaddo
//
//  Created by Tay on 10/29/26.
//

import SwiftUI

struct TripDatePickerView: View {
    enum SelectionMode {
        case range
        case single
    }

    let selectionMode: SelectionMode
    let selectedStartDate: Date?
    let selectedEndDate: Date?
    let onDateSelected: (Date) -> Void
    let onClose: () -> Void
    let onConfirm: () -> Void

    @State private var displayedMonth: Date
    @State private var isMonthYearPickerPresented = false

    private let calendar = Calendar.autoupdatingCurrent
    private let today: Date
    private let numberOfMonths: Int
    private let weekdaySymbols = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    init(
        selectionMode: SelectionMode = .range,
        selectedStartDate: Date?,
        selectedEndDate: Date?,
        today: Date = Date(),
        numberOfMonths: Int = 12,
        onDateSelected: @escaping (Date) -> Void,
        onClose: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        let calendar = Calendar.autoupdatingCurrent
        let normalizedToday = calendar.startOfDay(for: today)
        let initialDate = selectedStartDate ?? normalizedToday
        let initialMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: initialDate)
        ) ?? normalizedToday

        self.selectionMode = selectionMode
        self.selectedStartDate = selectedStartDate
        self.selectedEndDate = selectedEndDate
        self.today = normalizedToday
        self.numberOfMonths = max(numberOfMonths, 1)
        self.onDateSelected = onDateSelected
        self.onClose = onClose
        self.onConfirm = onConfirm
        _displayedMonth = State(initialValue: initialMonth)
    }

    var body: some View {
        VStack(spacing: DDSpacing.zero) {
            grabber
            modalHeader
            calendarView
            Spacer(minLength: DDSpacing.zero)
        }
        .frame(height: 526)
        .frame(maxWidth: .infinity)
        .background(DDColor.surfaceDefault)
        .overlay {
            RoundedRectangle(cornerRadius: 36)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .clipShape(.rect(topLeadingRadius: 36, topTrailingRadius: 36))
    }

    private var grabber: some View {
        Capsule()
            .fill(DDColor.actionSecondary)
            .frame(width: 140, height: 5)
            .padding(.top, DDSpacing.medium)
    }

    private var modalHeader: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "x.circle.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(DDColor.borderDefault)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("닫기")

            Spacer()

            Button(action: onConfirm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(
                        isSelectionComplete
                            ? DDColor.actionPrimary
                            : DDColor.actionSecondary
                    )
                    .frame(width: 44, height: 44)
            }
            .disabled(!isSelectionComplete)
            .accessibilityLabel("여행 날짜 확정")
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, DDSpacing.small)
        .padding(.bottom, DDSpacing.large)
    }

    private var calendarView: some View {
        VStack(spacing: DDSpacing.medium) {
            monthNavigation
            weekdayHeader

            VStack(spacing: 6) {
                ForEach(Array(monthWeeks(for: displayedMonth).enumerated()), id: \.offset) { _, week in
                    weekRow(week)
                }
            }
        }
        .padding(.horizontal, DDSpacing.xLarge)
    }

    private var monthNavigation: some View {
        HStack {
            Button {
                isMonthYearPickerPresented = true
            } label: {
                Text(monthTitle(for: displayedMonth))
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("연도와 월 선택")
            .popover(isPresented: $isMonthYearPickerPresented, arrowEdge: .top) {
                monthYearPicker
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            HStack(spacing: DDSpacing.xLarge) {
                monthNavigationButton(
                    systemName: "chevron.backward",
                    offset: -1,
                    label: "이전 달"
                )

                monthNavigationButton(
                    systemName: "chevron.forward",
                    offset: 1,
                    label: "다음 달"
                )
            }
        }
        .frame(height: 32)
    }

    private var monthYearPicker: some View {
        HStack(spacing: DDSpacing.zero) {
            Picker("연도", selection: displayedYearBinding) {
                ForEach(availableYears, id: \.self) { year in
                    Text(verbatim: "\(year)년")
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: 120)

            Picker("월", selection: displayedMonthBinding) {
                ForEach(availableMonths(for: displayedYear), id: \.self) { month in
                    Text("\(month)월")
                        .tag(month)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: 120)
        }
        .frame(width: 300, height: 156, alignment: .center)
        .clipped()
        .background(DDColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .presentationBackground(DDColor.surfaceElevated)
        .presentationCornerRadius(20)
        .preferredColorScheme(.dark)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: DDSpacing.zero) {
            ForEach(weekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DDColor.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 20)
    }

    private func monthNavigationButton(
        systemName: String,
        offset: Int,
        label: String
    ) -> some View {
        let isEnabled = canMoveMonth(by: offset)

        return Button {
            moveMonth(by: offset)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(DDColor.actionPrimary)
                .frame(width: 24, height: 32)
                .opacity(isEnabled ? 1 : 0.3)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private func weekRow(_ week: [Date?]) -> some View {
        GeometryReader { proxy in
            let cellWidth = proxy.size.width / 7
            let highlight = weekHighlight(in: week)

            ZStack(alignment: .leading) {
                if let highlight {
                    switch highlight {
                    case let .single(index):
                        Circle()
                            .fill(DDColor.surfaceControl)
                            .frame(width: 40, height: 40)
                            .offset(
                                x: (cellWidth * CGFloat(index)) + ((cellWidth - 40) / 2)
                            )

                    case let .range(selection):
                        UnevenRoundedRectangle(
                            cornerRadii: .init(
                                topLeading: selection.roundsLeadingEdge ? 20 : 0,
                                bottomLeading: selection.roundsLeadingEdge ? 20 : 0,
                                bottomTrailing: selection.roundsTrailingEdge ? 20 : 0,
                                topTrailing: selection.roundsTrailingEdge ? 20 : 0
                            ),
                            style: .continuous
                        )
                            .fill(DDColor.actionPrimary.opacity(0.4))
                            .frame(
                                width: max(
                                    40,
                                    (cellWidth * CGFloat(selection.dayCount))
                                        - selection.leadingInset
                                        - selection.trailingInset
                                ),
                                height: 40
                            )
                            .offset(
                                x: (cellWidth * CGFloat(selection.startIndex))
                                    + selection.leadingInset
                            )
                    }
                }

                HStack(spacing: DDSpacing.zero) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        dayCell(date)
                            .frame(width: cellWidth)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: highlight)
        }
        .frame(height: 40)
    }

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            let normalizedDate = calendar.startOfDay(for: date)
            let isPast = normalizedDate < today
            let isSingleSelected = isSingleSelection(normalizedDate)
            let isRangeSelected = isCompletedRangeSelection(normalizedDate)
            let isToday = calendar.isDate(normalizedDate, inSameDayAs: today)

            Button {
                onDateSelected(normalizedDate)
            } label: {
                Text("\(calendar.component(.day, from: normalizedDate))")
                    .font(
                        .system(
                            size: 20,
                            weight: isToday ? .bold : .regular
                        )
                    )
                    .foregroundStyle(
                        dayForegroundColor(
                            isSingleSelected: isSingleSelected,
                            isRangeSelected: isRangeSelected,
                            isToday: isToday,
                            isPast: isPast
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isPast)
            .accessibilityLabel(accessibilityDateFormatter.string(from: normalizedDate))
            .accessibilityAddTraits(
                (isSingleSelected || isRangeSelected) ? .isSelected : []
            )
        } else {
            Color.clear
        }
    }

    private func dayForegroundColor(
        isSingleSelected: Bool,
        isRangeSelected: Bool,
        isToday: Bool,
        isPast: Bool
    ) -> Color {
        if isSingleSelected || isToday {
            return DDColor.actionPrimary
        }

        if isRangeSelected {
            return DDColor.textPrimary
        }

        return isPast ? DDColor.textTertiary : DDColor.textPrimary
    }

    private var isSelectionComplete: Bool {
        switch selectionMode {
        case .range:
            selectedStartDate != nil && selectedEndDate != nil
        case .single:
            selectedStartDate != nil
        }
    }

    private func isSingleSelection(_ date: Date) -> Bool {
        guard let selectedStartDate else { return false }

        let showsSingleDate = selectionMode == .single || selectedEndDate == nil
        return showsSingleDate && calendar.isDate(date, inSameDayAs: selectedStartDate)
    }

    private func isCompletedRangeSelection(_ date: Date) -> Bool {
        guard
            selectionMode == .range,
            let selectedStartDate,
            let selectedEndDate
        else {
            return false
        }

        let start = calendar.startOfDay(for: selectedStartDate)
        let end = calendar.startOfDay(for: selectedEndDate)
        return date >= start && date <= end
    }

    private func weekHighlight(in week: [Date?]) -> WeekHighlight? {
        guard let selectedStartDate else { return nil }

        if selectionMode == .single || selectedEndDate == nil {
            guard let index = week.firstIndex(where: { date in
                guard let date else { return false }
                return calendar.isDate(date, inSameDayAs: selectedStartDate)
            }) else {
                return nil
            }

            return .single(index)
        }

        guard let selection = weekSelection(in: week) else { return nil }
        return .range(selection)
    }

    private func weekSelection(in week: [Date?]) -> WeekSelection? {
        guard
            let selectedStartDate,
            let selectedEndDate
        else {
            return nil
        }

        let selectedIndices = week.indices.filter { index in
            guard let date = week[index] else { return false }
            return isCompletedRangeSelection(date)
        }

        guard
            let firstIndex = selectedIndices.first,
            let lastIndex = selectedIndices.last
        else {
            return nil
        }

        guard
            let firstSelectedDate = week[firstIndex],
            let lastSelectedDate = week[lastIndex]
        else {
            return nil
        }

        let rangeStart = min(
            calendar.startOfDay(for: selectedStartDate),
            calendar.startOfDay(for: selectedEndDate)
        )
        let rangeEnd = max(
            calendar.startOfDay(for: selectedStartDate),
            calendar.startOfDay(for: selectedEndDate)
        )

        return WeekSelection(
            startIndex: firstIndex,
            endIndex: lastIndex,
            roundsLeadingEdge: rangeStart >= firstSelectedDate,
            roundsTrailingEdge: rangeEnd <= lastSelectedDate
        )
    }

    private func monthWeeks(for month: Date) -> [[Date?]] {
        guard
            let dayRange = calendar.range(of: .day, in: .month, for: month),
            let firstDate = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month)
            )
        else {
            return []
        }

        let leadingEmptyCount = calendar.component(.weekday, from: firstDate) - 1
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyCount)

        days.append(contentsOf: dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDate)
        })

        let trailingEmptyCount = (7 - (days.count % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: trailingEmptyCount))

        return stride(from: 0, to: days.count, by: 7).map { index in
            Array(days[index ..< min(index + 7, days.count)])
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private var earliestMonth: Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) ?? today
    }

    private var latestMonth: Date {
        calendar.date(
            byAdding: .month,
            value: numberOfMonths - 1,
            to: earliestMonth
        ) ?? earliestMonth
    }

    private var displayedYear: Int {
        calendar.component(.year, from: displayedMonth)
    }

    private var displayedMonthNumber: Int {
        calendar.component(.month, from: displayedMonth)
    }

    private var availableYears: [Int] {
        let firstYear = calendar.component(.year, from: earliestMonth)
        let lastYear = calendar.component(.year, from: latestMonth)
        return Array(firstYear ... lastYear)
    }

    private func availableMonths(for year: Int) -> [Int] {
        (1...12).filter { month in
            guard let date = calendar.date(
                from: DateComponents(year: year, month: month, day: 1)
            ) else {
                return false
            }

            return date >= earliestMonth && date <= latestMonth
        }
    }

    private var displayedYearBinding: Binding<Int> {
        Binding(
            get: { displayedYear },
            set: { year in
                updateDisplayedMonth(
                    year: year,
                    preferredMonth: displayedMonthNumber
                )
            }
        )
    }

    private var displayedMonthBinding: Binding<Int> {
        Binding(
            get: { displayedMonthNumber },
            set: { month in
                updateDisplayedMonth(
                    year: displayedYear,
                    preferredMonth: month
                )
            }
        )
    }

    private func updateDisplayedMonth(
        year: Int,
        preferredMonth: Int
    ) {
        let months = availableMonths(for: year)
        guard let fallbackMonth = months.first else { return }

        let month = months.contains(preferredMonth)
            ? preferredMonth
            : fallbackMonth

        guard let targetMonth = calendar.date(
            from: DateComponents(year: year, month: month, day: 1)
        ) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = targetMonth
        }
    }

    private func canMoveMonth(by offset: Int) -> Bool {
        guard let candidate = calendar.date(
            byAdding: .month,
            value: offset,
            to: displayedMonth
        ) else {
            return false
        }

        return candidate >= earliestMonth && candidate <= latestMonth
    }

    private func moveMonth(by offset: Int) {
        guard
            canMoveMonth(by: offset),
            let targetMonth = calendar.date(
                byAdding: .month,
                value: offset,
                to: displayedMonth
            )
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = targetMonth
        }
    }

    private var accessibilityDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }
}

private enum WeekHighlight: Equatable {
    case single(Int)
    case range(WeekSelection)
}

private struct WeekSelection: Equatable {
    let startIndex: Int
    let endIndex: Int
    let roundsLeadingEdge: Bool
    let roundsTrailingEdge: Bool

    var dayCount: Int {
        endIndex - startIndex + 1
    }

    var leadingInset: CGFloat {
        roundsLeadingEdge ? 1 : 0
    }

    var trailingInset: CGFloat {
        roundsTrailingEdge ? 1 : 0
    }
}

private func previewDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian).date(
        from: DateComponents(year: year, month: month, day: day)
    ) ?? Date()
}

#Preview("시작일 선택") {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.7)
            .ignoresSafeArea()

        TripDatePickerView(
            selectedStartDate: previewDate(year: 2026, month: 10, day: 20),
            selectedEndDate: nil,
            today: previewDate(year: 2026, month: 10, day: 8),
            onDateSelected: { _ in },
            onClose: {},
            onConfirm: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("범위 선택 완료") {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.7)
            .ignoresSafeArea()

        TripDatePickerView(
            selectedStartDate: previewDate(year: 2026, month: 10, day: 20),
            selectedEndDate: previewDate(year: 2026, month: 10, day: 25),
            today: previewDate(year: 2026, month: 10, day: 5),
            onDateSelected: { _ in },
            onClose: {},
            onConfirm: {}
        )
    }
    .preferredColorScheme(.dark)
}
