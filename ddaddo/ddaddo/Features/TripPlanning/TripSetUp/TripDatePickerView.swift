//
//  TripDatePickerView.swift
//  ddaddo
//

import SwiftUI

struct TripDatePickerView: View {
    let selectedStartDate: Date?
    let selectedEndDate: Date?
    let onDateSelected: (Date) -> Void
    let onClose: () -> Void
    let onConfirm: () -> Void

    private let calendar = Calendar.autoupdatingCurrent
    private let today: Date
    private let numberOfMonths: Int
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 0),
        count: 7
    )

    init(
        selectedStartDate: Date?,
        selectedEndDate: Date?,
        today: Date = Date(),
        numberOfMonths: Int = 12,
        onDateSelected: @escaping (Date) -> Void,
        onClose: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.selectedStartDate = selectedStartDate
        self.selectedEndDate = selectedEndDate
        self.today = Calendar.autoupdatingCurrent.startOfDay(for: today)
        self.numberOfMonths = numberOfMonths
        self.onDateSelected = onDateSelected
        self.onClose = onClose
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 0) {
            modalHeader

            ScrollView {
                LazyVStack(spacing: 36) {
                    ForEach(months, id: \.self) { month in
                        monthView(month)
                    }
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.xxLarge)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.black)
        .clipShape(
            .rect(
                topLeadingRadius: 36,
                topTrailingRadius: 36
            )
        )
    }

    private var modalHeader: some View {
        HStack {
            circleButton(
                systemName: "xmark",
                foregroundColor: DDColor.textSecondary,
                backgroundColor: DDColor.surfaceControl,
                action: onClose
            )
            .accessibilityLabel("여행 일정 선택 취소")

            Spacer()

            circleButton(
                systemName: "checkmark",
                foregroundColor: .white,
                backgroundColor: .blue,
                action: onConfirm
            )
            .disabled(!isSelectionComplete)
            .opacity(isSelectionComplete ? 1 : 0.4)
            .accessibilityLabel("여행 일정 선택 완료")
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .padding(.top, DDSpacing.xLarge)
        .padding(.bottom, DDSpacing.large)
    }

    private var months: [Date] {
        guard let currentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) else { return [] }

        return (0..<numberOfMonths).compactMap {
            calendar.date(byAdding: .month, value: $0, to: currentMonth)
        }
    }

    private var isSelectionComplete: Bool {
        selectedStartDate != nil && selectedEndDate != nil
    }

    private func monthView(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.large) {
            Text(monthTitle(month))
                .ddTypography(.heading20)
                .foregroundStyle(DDColor.textPrimary)

            LazyVGrid(columns: columns, spacing: DDSpacing.small) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .ddTypography(.caption12)
                        .foregroundStyle(DDColor.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
            }

            VStack(spacing: DDSpacing.small) {
                ForEach(Array(monthWeeks(month).enumerated()), id: \.offset) { _, week in
                    weekRow(week)
                }
            }
        }
    }

    private func weekRow(_ week: [Date?]) -> some View {
        ZStack(alignment: .leading) {
            GeometryReader { proxy in
                let cellWidth = proxy.size.width / 7
                let selection = weekSelection(in: week)

                Capsule()
                    .fill(DDColor.actionPrimary)
                    .frame(
                        width: cellWidth * CGFloat(selection?.dayCount ?? 0),
                        height: 40
                    )
                    .offset(x: cellWidth * CGFloat(selection?.startIndex ?? 0))
                    .opacity(selection == nil ? 0 : 1)
                    .animation(
                        rangeExpansionAnimation,
                        value: selection
                    )
            }
            .frame(height: 40)

            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                }
            }
        }
        .frame(height: 40)
    }

    private func dayCell(_ date: Date) -> some View {
        let isPast = date < today
        let isSelected = isDateInSelectedRange(date)

        return Button {
            onDateSelected(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .ddTypography(.label14)
                .foregroundStyle(
                    dayForegroundColor(
                        for: date,
                        isPast: isPast,
                        isSelected: isSelected
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .contentShape(.rect)
                .animation(rangeExpansionAnimation, value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
        .accessibilityLabel(accessibilityLabel(for: date))
    }

    private func monthWeeks(_ month: Date) -> [[Date?]] {
        guard
            let dayRange = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month)
            )
        else { return [] }

        let leadingEmptyCount = calendar.component(.weekday, from: firstDay) - 1
        var dates = Array<Date?>(repeating: nil, count: leadingEmptyCount)

        dates += dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }

        let trailingEmptyCount = (7 - dates.count % 7) % 7
        dates += Array<Date?>(repeating: nil, count: trailingEmptyCount)

        return stride(from: 0, to: dates.count, by: 7).map {
            Array(dates[$0..<min($0 + 7, dates.count)])
        }
    }

    private func weekSelection(in week: [Date?]) -> WeekSelection? {
        let selectedIndices = week.enumerated().compactMap { index, date -> Int? in
            guard let date, isDateInSelectedRange(date) else { return nil }
            return index
        }

        guard let startIndex = selectedIndices.first, let endIndex = selectedIndices.last else {
            return nil
        }

        return WeekSelection(startIndex: startIndex, endIndex: endIndex)
    }

    private func isDateInSelectedRange(_ date: Date) -> Bool {
        guard let selectedStartDate else { return false }

        guard let selectedEndDate else {
            return calendar.isDate(date, inSameDayAs: selectedStartDate)
        }

        return date >= selectedStartDate && date <= selectedEndDate
    }

    private var rangeExpansionAnimation: Animation? {
        selectedEndDate == nil ? nil : .easeInOut(duration: 0.25)
    }

    private func dayForegroundColor(
        for date: Date,
        isPast: Bool,
        isSelected: Bool
    ) -> Color {
        if isSelected {
            return DDColor.textOnPrimary
        }
        if isPast {
            return DDColor.textTertiary
        }
        if calendar.component(.weekday, from: date) == 1 {
            return DDColor.statusCritical
        }
        return DDColor.textPrimary
    }

    private func monthTitle(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)년 \(components.month ?? 0)월"
    }

    private func accessibilityLabel(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)년 \(components.month ?? 0)월 \(components.day ?? 0)일"
    }

    private func circleButton(
        systemName: String,
        foregroundColor: Color,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: 52, height: 52)
                .background(backgroundColor)
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
    }
}

private struct WeekSelection: Equatable {
    let startIndex: Int
    let endIndex: Int

    var dayCount: Int { endIndex - startIndex + 1 }
}

#Preview("날짜 미선택") {
    TripDatePickerView(
        selectedStartDate: nil,
        selectedEndDate: nil,
        onDateSelected: { _ in },
        onClose: {},
        onConfirm: {}
    )
    .frame(height: 710)
    .padding(.top, 80)
    .background(DDColor.surfaceElevated)
    .preferredColorScheme(.dark)
}

#Preview("범위 선택 완료") {
    let calendar = Calendar.autoupdatingCurrent
    let today = calendar.startOfDay(for: Date())

    TripDatePickerView(
        selectedStartDate: calendar.date(byAdding: .day, value: 3, to: today),
        selectedEndDate: calendar.date(byAdding: .day, value: 8, to: today),
        onDateSelected: { _ in },
        onClose: {},
        onConfirm: {}
    )
    .frame(height: 710)
    .padding(.top, 80)
    .background(DDColor.surfaceElevated)
    .preferredColorScheme(.dark)
}
