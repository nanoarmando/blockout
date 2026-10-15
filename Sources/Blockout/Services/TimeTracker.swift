import AppKit
import Foundation
import Observation
import SwiftData

/// The single timer. A running entry is saved when it starts (with no end) and a heartbeat is written every minute,
/// so an entry left open by a crash is closed at the last heartbeat on the next launch; a normal quit closes it at
/// the quit time. Every time-entry write (menu, task detail, notifications) goes through this service.
@MainActor
@Observable
final class TimeTracker {
    /// What the menu shows for the task after the timer stops. Pause and stop both close the entry (D5).
    enum IdleReason {
        case paused, stopped, completed
    }

    struct BlockExtension {
        let blockID: UUID
        var minutes: Int
        /// Original start of every block moved by the extensions, for the "antes → ahora" marks.
        var previousStarts: [UUID: Date]
        /// Blocks removed because they no longer fit in the working hours.
        var unplaced: [(title: String, start: Date)]
    }

    static let extensionMinutes = 15
    private static let heartbeatKey = "timerHeartbeat"

    private let context: ModelContext
    private let calendarService: CalendarService

    private var current: TimeEntry?
    private var lastIdle: (task: PlannerTask, entry: TimeEntry, reason: IdleReason)?
    private(set) var blockExtension: BlockExtension?
    /// Refreshed every 20 seconds so elapsed times and "now"-based lists stay current.
    private(set) var now = Date.now
    /// Start of the current day; changes only at midnight.
    private(set) var today = Calendar.planner.startOfDay(for: .now)
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(context: ModelContext, calendarService: CalendarService) {
        self.context = context
        self.calendarService = calendarService
        closeEntriesLeftOpen()
        calendarService.onTaskDone = { [weak self] task in
            if self?.isRunning(task) == true { self?.finish(.completed) }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeRunning(at: .now) }
        }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                self?.tick()
            }
        }
    }

    /// The running entry; `nil` once its task was deleted (e.g. through the MCP).
    var running: TimeEntry? { current.flatMap { $0.isLive ? $0 : nil } }

    /// The task whose timer was last paused, stopped or completed, with the entry that closed it.
    var idle: (task: PlannerTask, entry: TimeEntry, reason: IdleReason)? {
        lastIdle.flatMap { $0.task.isLive && $0.entry.isLive ? $0 : nil }
    }

    var runningTask: PlannerTask? { running?.task }

    func isRunning(_ task: PlannerTask) -> Bool { running?.task?.id == task.id }

    // MARK: Timer actions

    /// Starts the timer for `task`, closing the entry of any other running task first.
    func start(_ task: PlannerTask) {
        guard !isRunning(task) else { return }
        let start = Date.now
        closeRunning(at: start)
        let entry = TimeEntry(task: task, start: start)
        context.insert(entry)
        current = entry
        lastIdle = nil
        writeHeartbeat(start)
        save()
    }

    func pause() { finish(.paused) }

    /// Stops the running timer, or turns a pause into a stop.
    func stop() {
        if let paused = idle, paused.reason == .paused {
            lastIdle = (paused.task, paused.entry, .stopped)
        } else {
            finish(.stopped)
        }
    }

    /// Resumes the paused or stopped task with a new entry.
    func resume() {
        guard let task = idle?.task else { return }
        start(task)
    }

    /// Stops the timer and completes the task under the planner's rule (the block in progress is kept).
    func complete() {
        guard let task = running?.task ?? idle?.task else { return }
        finish(.completed)
        calendarService.complete(task)
        if let entry = idle?.entry { lastIdle = (task, entry, .completed) }
    }

    /// "+15 min" on the block in progress of the running task; later blocks follow `BlockCascade`.
    func extend(_ block: Block) {
        guard let task = running?.task, block.task?.id == task.id else { return }
        let titles = Dictionary(uniqueKeysWithValues: calendarService.blocks(in: Calendar.planner.dayInterval(containing: block.start)).map { ($0.id, $0.task?.title ?? "") })
        do {
            let result = try calendarService.extendBlock(block, by: Self.extensionMinutes)
            var summary = blockExtension.flatMap { $0.blockID == block.id ? $0 : nil }
                ?? BlockExtension(blockID: block.id, minutes: 0, previousStarts: [:], unplaced: [])
            summary.minutes += Self.extensionMinutes
            for move in result.moved where summary.previousStarts[move.id] == nil {
                summary.previousStarts[move.id] = move.from.start
            }
            summary.unplaced += result.removed.map { (title: titles[$0.id] ?? "", start: $0.interval.start) }
            blockExtension = summary
        } catch let error as CalendarWriteError {
            calendarService.writeError = error
        } catch {
            calendarService.otherErrorMessage = error.localizedDescription
        }
    }

    private func finish(_ reason: IdleReason) {
        guard let entry = running, let task = entry.task else { return }
        closeRunning(at: .now)
        lastIdle = (task, entry, reason)
    }

    private func closeRunning(at date: Date) {
        guard let entry = running else { return }
        entry.end = max(entry.start, date)
        current = nil
        UserDefaults.standard.removeObject(forKey: Self.heartbeatKey)
        save()
    }

    /// Closes entries a crash left open at the last heartbeat (or at their start when there is none).
    private func closeEntriesLeftOpen() {
        let open = (try? context.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.end == nil }))) ?? []
        guard !open.isEmpty else { return }
        let heartbeat = UserDefaults.standard.object(forKey: Self.heartbeatKey) as? Date
        for entry in open {
            entry.end = max(entry.start, heartbeat ?? entry.start)
        }
        UserDefaults.standard.removeObject(forKey: Self.heartbeatKey)
        save()
    }

    private func tick() {
        now = .now
        if running != nil { writeHeartbeat(now) }
        let startOfDay = Calendar.planner.startOfDay(for: now)
        if startOfDay != today {
            today = startOfDay
            blockExtension = nil
            lastIdle = nil
        }
    }

    private func writeHeartbeat(_ date: Date) {
        UserDefaults.standard.set(date, forKey: Self.heartbeatKey)
    }

    // MARK: Entry editing (task detail)

    /// Applies a new start or end; rejects a range whose end is before its start and returns `false`.
    @discardableResult
    func update(_ entry: TimeEntry, start: Date? = nil, end: Date? = nil) -> Bool {
        let newStart = start ?? entry.start
        let newEnd = end ?? entry.end
        if let newEnd, newEnd < newStart { return false }
        if entry === running, newStart > .now { return false }
        entry.start = newStart
        entry.end = newEnd
        save()
        return true
    }

    /// Adds a closed half-hour entry ending now, to be adjusted in the detail.
    func addManualEntry(to task: PlannerTask) {
        let end = Calendar.planner.date(bySetting: .second, value: 0, of: .now) ?? .now
        context.insert(TimeEntry(task: task, start: end.addingTimeInterval(-30 * 60), end: end))
        save()
    }

    func delete(_ entry: TimeEntry) {
        if entry === current {
            current = nil
            UserDefaults.standard.removeObject(forKey: Self.heartbeatKey)
        }
        if lastIdle?.entry === entry { lastIdle = nil }
        context.delete(entry)
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            calendarService.otherErrorMessage = error.localizedDescription
        }
    }
}

extension PersistentModel {
    /// Whether the model is still in the store (not deleted).
    var isLive: Bool { modelContext != nil && !isDeleted }
}

extension TimeEntry {
    /// Minutes until the end, or until `now` while running.
    func minutes(now: Date = .now) -> Int {
        max(0, Int((end ?? now).timeIntervalSince(start) / 60))
    }
}

extension PlannerTask {
    func trackedMinutes(now: Date = .now) -> Int {
        timeEntries.reduce(0) { $0 + $1.minutes(now: now) }
    }
}
