import AppKit
import EventKit
import Observation
import SwiftData
import SwiftUI

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    /// `false` for events marked as free (available): they are shown but never count as busy time.
    let isBusy: Bool

    var interval: DateInterval { DateInterval(start: start, end: max(start, end)) }

    /// Takes time in placement and free-time computations: timed and not marked as free.
    var takesTime: Bool { !isAllDay && isBusy }
}

struct CalendarInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let accountTitle: String
    let color: Color
    let isWritable: Bool

    /// "Trabajo (Google)"
    var displayName: String { "\(title) (\(accountTitle))" }
}

enum CalendarWriteError: LocalizedError {
    case notAuthorized
    case destinationUnavailable
    case eventMissing

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Blockout no tiene acceso a tus calendarios."
        case .destinationUnavailable: "El calendario de destino no existe o es de solo lectura. Elige un calendario con permiso de escritura en Ajustes."
        case .eventMissing: "El evento de este bloque ya no existe en el calendario."
        }
    }
}

/// Reads macOS calendars and mirrors Blockout blocks as events. Every block write saves the event first and
/// commits the SwiftData change only when the event was saved, so no block exists without its event.
@MainActor
@Observable
final class CalendarService {
    static let blockURLScheme = "blockout"

    private let store = EKEventStore()
    private let context: ModelContext
    private let settingsStore: SettingsStore
    @ObservationIgnored private var reconcileTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoaded = false

    private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    private(set) var calendars: [CalendarInfo] = []
    /// Bumped whenever calendar data may have changed, so views reload their events.
    private(set) var revision = 0
    var writeError: CalendarWriteError?
    var otherErrorMessage: String?
    /// Called after a task is completed from any path (list, detail, menu, MCP); `TimeTracker` stops its timer.
    @ObservationIgnored var onTaskDone: ((PlannerTask) -> Void)?

    var hasAccess: Bool { authorization == .fullAccess }
    var writableCalendars: [CalendarInfo] { calendars.filter(\.isWritable) }

    init(context: ModelContext, settingsStore: SettingsStore) {
        self.context = context
        self.settingsStore = settingsStore
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleReconcile() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAuthorization() }
        }
    }

    // MARK: Access and calendars

    func requestAccessIfNeeded() async {
        if authorization == .notDetermined {
            _ = try? await store.requestFullAccessToEvents()
        }
        refreshAuthorization()
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshAuthorization() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        guard hasAccess else { return }
        loadCalendars()
        if !hasLoaded {
            hasLoaded = true
            reconcile()
        }
    }

    private func loadCalendars() {
        calendars = store.calendars(for: .event)
            .map { calendar in
                CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    accountTitle: calendar.source?.title ?? "Otros",
                    color: Color(cgColor: calendar.cgColor),
                    isWritable: calendar.allowsContentModifications
                )
            }
            .sorted { ($0.accountTitle, $0.title) < ($1.accountTitle, $1.title) }
        if settingsStore.settings.destinationCalendarID == nil,
           let fallback = store.defaultCalendarForNewEvents, fallback.allowsContentModifications {
            settingsStore.settings.destinationCalendarID = fallback.calendarIdentifier
        }
    }

    // MARK: Reading

    /// Timed and all-day events of the calendars that are read, without the events that mirror blocks.
    func events(in interval: DateInterval) -> [CalendarEvent] {
        guard hasAccess else { return [] }
        let readIDs = settingsStore.settings.readCalendarIDs
        let readCalendars = store.calendars(for: .event).filter { readIDs?.contains($0.calendarIdentifier) ?? true }
        // An empty calendar list means "all calendars" to EventKit, so an empty selection must return early.
        guard !readCalendars.isEmpty else { return [] }
        let blockEventIDs = Set(((try? context.fetch(FetchDescriptor<Block>())) ?? []).compactMap(\.eventIdentifier))
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: readCalendars)
        return store.events(matching: predicate)
            .filter { $0.url?.scheme != Self.blockURLScheme && !blockEventIDs.contains($0.eventIdentifier ?? "") }
            .map { event in
                CalendarEvent(
                    id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                    title: event.title ?? "",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    isBusy: event.availability != .free
                )
            }
    }

    /// Confirmed blocks overlapping `interval`; drafts are not reservations.
    func blocks(in interval: DateInterval) -> [Block] {
        let start = interval.start, end = interval.end
        let confirmed = BlockState.confirmed.rawValue
        let descriptor = FetchDescriptor<Block>(predicate: #Predicate { $0.start < end && $0.end > start && $0.stateRaw == confirmed })
        return (try? context.fetch(descriptor)) ?? []
    }

    func drafts() -> [Block] {
        let draft = BlockState.draft.rawValue
        let descriptor = FetchDescriptor<Block>(predicate: #Predicate { $0.stateRaw == draft }, sortBy: [SortDescriptor(\.start)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Timed events and confirmed blocks of the day containing `date`: what a new placement must not overlap.
    func busyIntervals(on date: Date) -> [DateInterval] {
        let calendar = Calendar.planner
        let start = calendar.startOfDay(for: date)
        let day = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
        return events(in: day).filter(\.takesTime).map(\.interval) + blocks(in: day).map(\.interval)
    }

    /// Whether `interval` lies inside the working hours of its day without overlapping events or confirmed blocks.
    func isFree(_ interval: DateInterval) -> Bool {
        guard let workday = settingsStore.settings.workday(containing: interval.start),
              interval.start >= workday.start, interval.end <= workday.end else { return false }
        return !busyIntervals(on: interval.start).contains { $0.start < interval.end && $0.end > interval.start }
    }

    /// "En «Trabajo» (Google) como ocupado", or `nil` when the event cannot be found.
    func eventSummary(for block: Block) -> String? {
        guard let event = event(for: block), let calendar = event.calendar else { return nil }
        let availability = event.availability == .free ? "disponible" : "ocupado"
        return "En «\(calendar.title)» (\(calendar.source?.title ?? "Otros")) como \(availability)"
    }

    // MARK: Block writes
    // The Bool variants report failures through the UI alerts; the throwing ones are shared with the MCP tools.

    @discardableResult
    func createBlock(for task: PlannerTask, start: Date, end: Date) -> Bool {
        perform { try insertBlock(for: task, start: start, end: end) } != nil
    }

    @discardableResult
    func moveBlock(_ block: Block, start: Date, end: Date) -> Bool {
        perform { try updateBlock(block, start: start, end: end) } != nil
    }

    @discardableResult
    func deleteBlock(_ block: Block) -> Bool {
        perform { try removeBlock(block) } != nil
    }

    /// Marks the task done, keeping past blocks and deleting the ones that have not started yet.
    func complete(_ task: PlannerTask) {
        perform { try markDone(task) }
    }

    @discardableResult
    func insertBlock(for task: PlannerTask, start: Date, end: Date) throws -> Block {
        let blockID = UUID()
        let event = try saveEvent(blockID: blockID, title: task.blockTitle, start: start, end: end)
        let block = Block(id: blockID, task: task, start: start, end: end, eventIdentifier: event.eventIdentifier)
        context.insert(block)
        try commit(removingOnFailure: event)
        return block
    }

    /// Drafts only change in the store; confirmed blocks move their event first.
    func updateBlock(_ block: Block, start: Date, end: Date) throws {
        if !block.isDraft {
            guard hasAccess else { throw CalendarWriteError.notAuthorized }
            guard let event = event(for: block) else { throw CalendarWriteError.eventMissing }
            event.startDate = start
            event.endDate = end
            try store.save(event, span: .thisEvent, commit: true)
        }
        block.start = start
        block.end = end
        try commit()
    }

    func removeBlock(_ block: Block) throws {
        if !block.isDraft {
            guard hasAccess else { throw CalendarWriteError.notAuthorized }
            if let event = event(for: block) {
                try store.remove(event, span: .thisEvent, commit: true)
            }
        }
        context.delete(block)
        try commit()
    }

    /// Rewrites the event titles of all the tasks' confirmed blocks (past included) in one EventKit commit.
    /// Called after a title, project or project-name change; event titles are never copied back to tasks.
    func retitleEvents(of tasks: [PlannerTask]) throws {
        guard tasks.contains(where: { !$0.confirmedBlocks.isEmpty }) else { return }
        guard hasAccess else { throw CalendarWriteError.notAuthorized }
        var changed = false
        for task in tasks {
            for block in task.confirmedBlocks {
                guard let event = event(for: block), event.title != task.blockTitle else { continue }
                event.title = task.blockTitle
                try store.save(event, span: .thisEvent, commit: false)
                changed = true
            }
        }
        guard changed else { return }
        do {
            try store.commit()
        } catch {
            store.reset()
            throw error
        }
    }

    /// UI entry point for `retitleEvents(of:)`: failures are shown, the task change is kept.
    func syncEventTitles(of tasks: [PlannerTask]) {
        perform { try retitleEvents(of: tasks) }
    }

    /// Deletes the task with all its blocks (past, future and drafts) and their events; time entries cascade.
    /// Shared by the task list and the MCP `delete_task`.
    func removeTask(_ task: PlannerTask) throws {
        for block in task.blocks {
            try removeBlock(block)
        }
        context.delete(task)
        try commit()
    }

    @discardableResult
    func deleteTask(_ task: PlannerTask) -> Bool {
        perform { try removeTask(task) } != nil
    }

    func markDone(_ task: PlannerTask) throws {
        let now = Date.now
        for block in task.blocks.filter({ $0.start > now }) {
            try removeBlock(block)
        }
        task.status = .done
        try commit()
        onTaskDone?(task)
    }

    /// Extends a confirmed block and applies the cascade of later blocks (moves and removals) in one EventKit
    /// commit, then one store save; on failure nothing changes.
    func extendBlock(_ block: Block, by minutes: Int) throws -> BlockCascade.Result {
        guard hasAccess else { throw CalendarWriteError.notAuthorized }
        let newEnd = block.end.addingTimeInterval(TimeInterval(minutes * 60))
        let day = Calendar.planner.dayInterval(containing: block.start)
        let later = blocks(in: day).filter { $0.id != block.id && $0.start >= block.start }
        let workdayEnd = settingsStore.settings.workday(containing: block.start)?.end ?? day.end
        let result = BlockCascade.cascade(
            blocks: later.map { BlockCascade.Item(id: $0.id, interval: $0.interval) },
            events: events(in: day).filter(\.takesTime).map(\.interval),
            from: newEnd,
            workdayEnd: workdayEnd
        )
        let byID = Dictionary(uniqueKeysWithValues: later.map { ($0.id, $0) })
        do {
            guard let extended = event(for: block) else { throw CalendarWriteError.eventMissing }
            extended.endDate = newEnd
            try store.save(extended, span: .thisEvent, commit: false)
            for move in result.moved {
                guard let moved = byID[move.id], let event = event(for: moved) else { throw CalendarWriteError.eventMissing }
                event.startDate = move.to.start
                event.endDate = move.to.end
                try store.save(event, span: .thisEvent, commit: false)
            }
            for item in result.removed {
                if let removed = byID[item.id], let event = event(for: removed) {
                    try store.remove(event, span: .thisEvent, commit: false)
                }
            }
            try store.commit()
        } catch {
            store.reset()
            throw error
        }
        block.end = newEnd
        for move in result.moved {
            byID[move.id]?.start = move.to.start
            byID[move.id]?.end = move.to.end
        }
        result.removed.compactMap { byID[$0.id] }.forEach(context.delete)
        try commit()
        return result
    }

    @discardableResult
    private func perform<Result>(_ write: () throws -> Result) -> Result? {
        do {
            return try write()
        } catch let error as CalendarWriteError {
            writeError = error
        } catch {
            otherErrorMessage = error.localizedDescription
        }
        return nil
    }

    /// Saves the store; on failure discards the pending changes and removes the event written for them.
    private func commit(removingOnFailure event: EKEvent? = nil) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            if let event { try? store.remove(event, span: .thisEvent, commit: true) }
            throw error
        }
        revision += 1
    }

    /// Writes the event that mirrors `block` in the destination calendar.
    private func saveEvent(blockID: UUID, title: String, start: Date, end: Date) throws -> EKEvent {
        guard hasAccess else { throw CalendarWriteError.notAuthorized }
        let event = EKEvent(eventStore: store)
        event.calendar = try destinationCalendar()
        event.title = title
        event.startDate = start
        event.endDate = end
        event.availability = settingsStore.settings.blocksShowAsBusy ? .busy : .free
        event.url = Self.url(for: blockID)
        event.notes = "Bloque de Blockout."
        try store.save(event, span: .thisEvent, commit: true)
        return event
    }

    private func destinationCalendar() throws -> EKCalendar {
        guard let id = settingsStore.settings.destinationCalendarID,
              let calendar = store.calendar(withIdentifier: id),
              calendar.allowsContentModifications
        else { throw CalendarWriteError.destinationUnavailable }
        return calendar
    }

    // MARK: Drafts

    /// Replaces every existing draft with a new proposal. Drafts never reach the calendar.
    func replaceDrafts(with items: [(task: PlannerTask, interval: DateInterval)]) throws -> [Block] {
        let proposalID = UUID()
        drafts().forEach(context.delete)
        let created = items.map { item in
            Block(id: UUID(), task: item.task, start: item.interval.start, end: item.interval.end, eventIdentifier: nil, state: .draft, proposalID: proposalID)
        }
        created.forEach(context.insert)
        try commit()
        return created
    }

    /// Turns drafts into blocks and writes their events, revalidating each one first. Drafts that no longer fit
    /// stay visible as drafts and are named in a message.
    func acceptDrafts(_ drafts: [Block]) {
        let skipped = perform {
            var notPlaced: [Block] = []
            for draft in drafts.sorted(by: { $0.start < $1.start }) {
                guard let task = draft.task, isFree(draft.interval) else {
                    notPlaced.append(draft)
                    continue
                }
                let event = try saveEvent(blockID: draft.id, title: task.blockTitle, start: draft.start, end: draft.end)
                draft.eventIdentifier = event.eventIdentifier
                draft.stateRaw = BlockState.confirmed.rawValue
                try commit(removingOnFailure: event)
            }
            return notPlaced
        }
        guard let skipped, !skipped.isEmpty else { return }
        let names = skipped.map { "«\($0.task?.title ?? "")» (\(PlannerFormat.dayMonth($0.start)) · \(PlannerFormat.timeRange($0.start, $0.end)))" }
        otherErrorMessage = "Estos bloques propuestos ya no tienen espacio libre y siguen como propuestas: " + names.joined(separator: ", ") + "."
    }

    func discardDrafts(_ drafts: [Block]) {
        perform {
            drafts.forEach(context.delete)
            try commit()
        }
    }

    // MARK: Reconciliation

    private func scheduleReconcile() {
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.loadCalendars()
            self?.reconcile()
        }
    }

    /// Updates blocks whose events were moved or resized elsewhere and deletes blocks whose events are gone.
    private func reconcile() {
        guard hasAccess else { return }
        // Drafts have no event, so they are never reconciled.
        let confirmedBlocks = blocks(in: DateInterval(start: .distantPast, end: .distantFuture))
        // While the destination account is missing (e.g. macOS is resyncing it), missing events are not proof of deletion.
        let canDelete = (try? destinationCalendar()) != nil
        for block in confirmedBlocks {
            guard let event = event(for: block) else {
                if canDelete { context.delete(block) }
                continue
            }
            if block.eventIdentifier != event.eventIdentifier { block.eventIdentifier = event.eventIdentifier }
            if block.start != event.startDate { block.start = event.startDate }
            if block.end != event.endDate { block.end = event.endDate }
        }
        if context.hasChanges { try? context.save() }
        revision += 1
    }

    /// The block's event by identifier, falling back to the `blockout://block/<id>` URL around the block date.
    private func event(for block: Block) -> EKEvent? {
        if let identifier = block.eventIdentifier, let event = store.event(withIdentifier: identifier) {
            return event
        }
        let url = Self.url(for: block.id)
        let margin: TimeInterval = 14 * 24 * 3600
        let predicate = store.predicateForEvents(
            withStart: block.start.addingTimeInterval(-margin),
            end: block.end.addingTimeInterval(margin),
            calendars: nil
        )
        return store.events(matching: predicate).first { $0.url == url }
    }

    private static func url(for blockID: UUID) -> URL {
        URL(string: "\(blockURLScheme)://block/\(blockID.uuidString.lowercased())")!
    }
}
