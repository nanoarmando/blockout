import Foundation

enum CalendarMode: Equatable {
    case day, days, week, month
}

/// The visible calendar range: the mode plus an anchor day that navigation moves.
struct CalendarRange: Equatable {
    var mode = CalendarMode.week
    var dayCount = 3
    var anchor = Calendar.planner.startOfDay(for: .now)

    private var calendar: Calendar { .planner }

    /// Columns of the time-based views.
    var days: [Date] {
        switch mode {
        case .day: [anchor]
        case .days: dates(from: anchor, count: dayCount)
        case .week: dates(from: startOfWeek(anchor), count: 5)
        case .month: []
        }
    }

    /// Cells of the month grid: whole weeks from Monday covering the anchor's month.
    var monthCells: [Date] {
        guard let month = calendar.dateInterval(of: .month, for: anchor) else { return [] }
        let first = startOfWeek(month.start)
        let lastDay = month.end.addingTimeInterval(-1)
        let last = calendar.date(byAdding: .day, value: 6, to: startOfWeek(lastDay)) ?? lastDay
        let count = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
        return dates(from: first, count: count)
    }

    var fetchInterval: DateInterval {
        let visible = mode == .month ? monthCells : days
        let start = visible.first ?? anchor
        let end = calendar.date(byAdding: .day, value: 1, to: visible.last ?? anchor) ?? anchor
        return DateInterval(start: start, end: end)
    }

    var title: String {
        if mode == .month { return PlannerFormat.monthTitle(anchor) }
        return PlannerFormat.rangeTitle(first: days.first ?? anchor, last: days.last ?? anchor)
    }

    mutating func step(_ direction: Int) {
        let (component, value): (Calendar.Component, Int) = switch mode {
        case .day: (.day, 1)
        case .days: (.day, dayCount)
        case .week: (.weekOfYear, 1)
        case .month: (.month, 1)
        }
        anchor = calendar.date(byAdding: component, value: value * direction, to: anchor) ?? anchor
    }

    mutating func goToToday() {
        anchor = calendar.startOfDay(for: .now)
    }

    private func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func dates(from start: Date, count: Int) -> [Date] {
        (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
