import Foundation

/// Pure scheduling helpers shared by the drag preview and the drop.
enum SlotFinder {
    static let stepMinutes = 15

    /// Rounds a minute offset down to the 15-minute grid.
    static func snap(minutes: Int) -> Int {
        Int((Double(minutes) / Double(stepMinutes)).rounded(.down)) * stepMinutes
    }

    /// The first start at or after `desired` where `duration` fits inside `workday` without overlapping `busy`,
    /// or `nil` when nothing fits before the end of the working hours.
    static func nextFreeStart(from desired: Date, duration: TimeInterval, busy: [DateInterval], workday: DateInterval) -> Date? {
        guard duration <= workday.duration else { return nil }
        var start = min(max(desired, workday.start), workday.end.addingTimeInterval(-duration))
        while true {
            let end = start.addingTimeInterval(duration)
            let overlapping = busy.filter { $0.start < end && $0.end > start }
            guard let latestEnd = overlapping.map(\.end).max() else { break }
            start = latestEnd
        }
        return start.addingTimeInterval(duration) <= workday.end ? start : nil
    }

    /// Free time inside `workday`, counting overlapping busy intervals once.
    static func freeDuration(in workday: DateInterval, busy: [DateInterval]) -> TimeInterval {
        let clipped = busy.compactMap { $0.intersection(with: workday) }.sorted { $0.start < $1.start }
        var busyTotal: TimeInterval = 0
        var current: DateInterval?
        for interval in clipped {
            if let running = current, interval.start <= running.end {
                current = DateInterval(start: running.start, end: max(running.end, interval.end))
            } else {
                busyTotal += current?.duration ?? 0
                current = interval
            }
        }
        busyTotal += current?.duration ?? 0
        return max(0, workday.duration - busyTotal)
    }
}
