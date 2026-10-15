import Foundation

extension Calendar {
    /// Gregorian calendar with weeks starting on Monday, used everywhere in the planner.
    static let planner: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .planner
        calendar.firstWeekday = 2
        return calendar
    }()

    /// The whole calendar day containing `date`.
    func dayInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .day, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 86_400)
    }
}

extension Locale {
    /// Spanish texts with the hour cycle the user chose in macOS (12 or 24 hours), for date pickers and the calendar.
    static let planner: Locale = {
        var components = Locale.Components(identifier: "es")
        components.hourCycle = PlannerFormat.uses12HourClock ? .oneToTwelve : .zeroToTwentyThree
        return Locale(components: components)
    }()
}

/// Spanish date and duration labels matching the mockup ("Jue 15 oct", "16:00" or "4:00 pm", "1.5h").
enum PlannerFormat {
    /// Whether macOS shows times with am/pm, from the system locale and its 12/24-hour setting.
    static let uses12HourClock = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? false

    private static let weekdays = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
    private static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    private static let fullMonths = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    static let weekdayHeaders = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

    private static var calendar: Calendar { .planner }

    static func weekday(_ date: Date) -> String { weekdays[calendar.component(.weekday, from: date) - 1] }
    static func month(_ date: Date) -> String { months[calendar.component(.month, from: date) - 1] }
    static func day(_ date: Date) -> Int { calendar.component(.day, from: date) }
    static func year(_ date: Date) -> Int { calendar.component(.year, from: date) }

    static func time(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0, minute = parts.minute ?? 0
        guard uses12HourClock else { return String(format: "%d:%02d", hour, minute) }
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, minute, hour < 12 ? "am" : "pm")
    }

    /// Hour column label: "9:00", or "9 am" with a 12-hour clock.
    static func hourLabel(_ hour: Int) -> String {
        guard uses12HourClock else { return "\(hour):00" }
        return "\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "am" : "pm")"
    }

    static func timeRange(_ start: Date, _ end: Date) -> String { "\(time(start)) – \(time(end))" }

    /// "Jue 15 oct"
    static func dayMonth(_ date: Date) -> String { "\(weekday(date)) \(day(date)) \(month(date))" }

    /// "Octubre 2026"
    static func monthTitle(_ date: Date) -> String { "\(fullMonths[calendar.component(.month, from: date) - 1]) \(year(date))" }

    /// "Jue 15 oct 2026", "15 – 17 oct 2026" or "28 sep – 2 oct 2026".
    static func rangeTitle(first: Date, last: Date) -> String {
        if calendar.isDate(first, inSameDayAs: last) { return "\(dayMonth(first)) \(year(first))" }
        let sameMonth = calendar.isDate(first, equalTo: last, toGranularity: .month)
        let sameYear = calendar.isDate(first, equalTo: last, toGranularity: .year)
        let head = sameMonth ? "\(day(first))" : "\(day(first)) \(month(first))" + (sameYear ? "" : " \(year(first))")
        return "\(head) – \(day(last)) \(month(last)) \(year(last))"
    }

    /// When the next block happens: "Jue 16:00", or with the date when it is a week or more away.
    static func nextBlock(_ date: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: date).day ?? 0
        return days < 7 ? "\(weekday(date)) \(time(date))" : "\(dayMonth(date)) \(time(date))"
    }

    static func due(_ date: Date, overdue: Bool) -> String {
        if calendar.isDateInToday(date) { return "Vence hoy" }
        return "\(overdue ? "Venció" : "Vence") \(day(date)) \(month(date))"
    }

    /// "1h", "1.5h", "45m"
    static func hours(minutes: Int) -> String {
        if minutes == 0 { return "0h" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = Double(minutes) / 60
        return hours == hours.rounded() ? "\(Int(hours))h" : String(format: "%.1fh", hours).replacingOccurrences(of: ".0h", with: "h")
    }

    /// "0:24", the elapsed time of a timer.
    static func clock(minutes: Int) -> String { String(format: "%d:%02d", minutes / 60, minutes % 60) }

    /// "1h 05m", recorded time in the task detail.
    static func hoursMinutes(_ minutes: Int) -> String { String(format: "%dh %02dm", minutes / 60, minutes % 60) }

    /// "Checkout…": the first word of a title, for the menu bar item.
    static func shortTitle(_ title: String) -> String {
        let words = title.split(whereSeparator: \.isWhitespace)
        guard let first = words.first else { return "" }
        let word = first.count > 14 ? String(first.prefix(13)) : String(first)
        return words.count > 1 || word.count < first.count ? word + "…" : word
    }

    /// The title cut to `limit` characters with an ellipsis, for menu items.
    static func truncated(_ title: String, limit: Int = 40) -> String {
        title.count > limit ? String(title.prefix(limit - 1)) + "…" : title
    }

    /// "Libre 8h 30m"
    static func free(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let rest = minutes % 60
        return "Libre \(minutes / 60)h" + (rest > 0 ? " \(rest)m" : "")
    }
}
