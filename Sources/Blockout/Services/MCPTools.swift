import Foundation
import SwiftData

struct ToolError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// The MCP tools. Handlers run on the main actor and go through the same context, `CalendarService` and
/// `SlotFinder` as the views, so the MCP and the UI follow the same rules. Every handler validates its arguments
/// before changing anything, so a failed call leaves the data unchanged.
@MainActor
final class MCPTools {
    private let context: ModelContext
    private let calendarService: CalendarService
    private let settingsStore: SettingsStore

    init(context: ModelContext, calendarService: CalendarService, settingsStore: SettingsStore) {
        self.context = context
        self.calendarService = calendarService
        self.settingsStore = settingsStore
    }

    /// The `tools/call` result: the handler's JSON as text content, or `isError` with the message.
    func call(_ name: String, arguments: [String: Any]) -> [String: Any] {
        do {
            guard let handler = handlers[name] else { throw ToolError("unknown tool: \(name)") }
            let result = try handler(ToolArguments(arguments))
            return ["content": [["type": "text", "text": Self.encode(result)]], "isError": false]
        } catch let error as ToolError {
            return Self.errorResult(error.message)
        } catch {
            return Self.errorResult(error.localizedDescription)
        }
    }

    private static func errorResult(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }

    private static func encode(_ object: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    private var handlers: [String: (ToolArguments) throws -> [String: Any]] {
        [
            "list_projects": listProjects,
            "create_project": createProject,
            "list_tasks": listTasks,
            "create_task": createTask,
            "update_task": updateTask,
            "delete_task": deleteTask,
            "get_schedule": getSchedule,
            "schedule_task": scheduleTask,
            "update_block": updateBlock,
            "delete_block": deleteBlock,
            "propose_blocks": proposeBlocks,
            "list_time_entries": listTimeEntries,
        ]
    }

    // MARK: Projects

    private func listProjects(_ arguments: ToolArguments) throws -> [String: Any] {
        let projects = try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)]))
        return ["projects": projects.map(json)]
    }

    private func createProject(_ arguments: ToolArguments) throws -> [String: Any] {
        let name = try arguments.requiredString("name")
        let color = try arguments.int("color")
        if let color, !(0..<ProjectPalette.count).contains(color) {
            throw ToolError("color must be between 0 and \(ProjectPalette.count - 1)")
        }
        let existed = try findProject(named: name) != nil
        guard let project = try context.project(named: name) else { throw ToolError("name must not be empty") }
        if !existed, let color {
            project.colorIndex = color
            try context.save()
        }
        return ["project": json(project), "created": !existed]
    }

    private func findProject(named name: String) throws -> Project? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try context.fetch(FetchDescriptor<Project>()).first { $0.name.compare(needle, options: .caseInsensitive) == .orderedSame }
    }

    /// A project by id or case-insensitive name.
    private func existingProject(_ reference: String) throws -> Project {
        if let id = UUID(uuidString: reference),
           let project = try context.fetch(FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })).first {
            return project
        }
        guard let project = try findProject(named: reference) else { throw ToolError("project not found: \(reference)") }
        return project
    }

    // MARK: Tasks

    private func listTasks(_ arguments: ToolArguments) throws -> [String: Any] {
        let status = try arguments.string("status").map(Self.status)
        let project = try arguments.string("project").map(existingProject)
        let includeDone = try arguments.bool("include_done") ?? false
        let tasks = try allTasks().filter { task in
            (status.map { task.status == $0 } ?? (includeDone || task.isOpen))
                && (project.map { task.project?.id == $0.id } ?? true)
        }
        return ["tasks": tasks.map(json)]
    }

    private func createTask(_ arguments: ToolArguments) throws -> [String: Any] {
        let title = try arguments.requiredString("title")
        let fields = try TaskFields(arguments)
        let allowDuplicate = try arguments.bool("allow_duplicate") ?? false

        if !allowDuplicate, let (task, reason) = try duplicate(title: title, externalRef: fields.externalRef ?? nil) {
            return ["task": json(task), "created": false, "duplicate_by": reason]
        }
        let project = try fields.projectReference.map { try $0.map(resolveProject) } ?? nil
        let task = PlannerTask(title: title, project: project)
        context.insert(task)
        fields.apply(to: task)
        if let status = fields.status { task.status = status }
        try context.save()
        return ["task": json(task), "created": true]
    }

    /// An existing task with the same external reference (any status) or the same title (open tasks only).
    private func duplicate(title: String, externalRef: ExternalRef?) throws -> (PlannerTask, String)? {
        let tasks = try allTasks()
        if let externalRef,
           let match = tasks.first(where: { $0.externalRefID == externalRef.id && $0.externalRefLabel?.caseInsensitiveCompare(externalRef.label) == .orderedSame }) {
            return (match, "external_ref")
        }
        if let match = tasks.first(where: { $0.isOpen && $0.title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(title) == .orderedSame }) {
            return (match, "title")
        }
        return nil
    }

    private func updateTask(_ arguments: ToolArguments) throws -> [String: Any] {
        let task = try existingTask(arguments.requiredUUID("id"))
        let title = try arguments.string("title")
        if let title, title.isEmpty { throw ToolError("title must not be empty") }
        let fields = try TaskFields(arguments)
        let project = try fields.projectReference.map { try $0.map(resolveProject) }

        // Completing goes first: it is the only step that can fail on the calendar, and it follows the UI rule.
        if fields.status == .done, task.status != .done {
            try calendarService.markDone(task)
        }
        let previousBlockTitle = task.blockTitle
        if let title { task.title = title }
        if let project { task.project = project }
        fields.apply(to: task)
        try context.save()
        // The task change is kept even when its events cannot be retitled; the result says why
        if task.blockTitle != previousBlockTitle {
            do {
                try calendarService.retitleEvents(of: [task])
            } catch {
                return ["task": json(task), "warning": "event titles not updated: \(error.localizedDescription)"]
            }
        }
        return ["task": json(task)]
    }

    private func deleteTask(_ arguments: ToolArguments) throws -> [String: Any] {
        let task = try existingTask(arguments.requiredUUID("id"))
        guard try arguments.bool("confirm") == true else {
            return ["requires_confirmation": true, "would_delete": ["task": json(task), "blocks": task.blocks.sorted { $0.start < $1.start }.map(json)]]
        }
        let summary = json(task)
        try calendarService.removeTask(task)
        return ["deleted": ["task": summary]]
    }

    /// A project reference from create or update: an existing id, or a name reused case-insensitively or created.
    private func resolveProject(_ reference: String) throws -> Project {
        if let id = UUID(uuidString: reference) { return try existingProject(id.uuidString) }
        guard let project = try context.project(named: reference) else { throw ToolError("project must not be empty") }
        return project
    }

    private func allTasks() throws -> [PlannerTask] {
        try context.fetch(FetchDescriptor<PlannerTask>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }

    private func existingTask(_ id: UUID) throws -> PlannerTask {
        guard let task = try context.fetch(FetchDescriptor<PlannerTask>(predicate: #Predicate { $0.id == id })).first else {
            throw ToolError("task not found: \(id.uuidString.lowercased())")
        }
        return task
    }

    private func existingBlock(_ id: UUID) throws -> Block {
        guard let block = try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == id })).first else {
            throw ToolError("block not found: \(id.uuidString.lowercased())")
        }
        return block
    }

    // MARK: Schedule and blocks

    private func getSchedule(_ arguments: ToolArguments) throws -> [String: Any] {
        let calendar = Calendar.planner
        let from = try calendar.startOfDay(for: arguments.date("from") ?? .now)
        let dayCount = try arguments.int("days") ?? 1
        guard (1...31).contains(dayCount) else { throw ToolError("days must be between 1 and 31") }
        guard let end = calendar.date(byAdding: .day, value: dayCount, to: from) else { throw ToolError("invalid date range") }
        let range = DateInterval(start: from, end: end)
        let events = calendarService.events(in: range)
        let blocks = calendarService.blocks(in: range)
        let drafts = calendarService.drafts().filter { $0.start < end && $0.end > from }

        let days: [[String: Any]] = (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: from) else { return nil }
            let onDay: (Date) -> Bool = { calendar.isDate($0, inSameDayAs: day) }
            let dayEvents = events.filter { onDay($0.start) }
            let dayBlocks = blocks.filter { onDay($0.start) }
            let workday = settingsStore.settings.workday(containing: day)
            let busy = dayEvents.filter { !$0.isAllDay }.map(\.interval) + dayBlocks.map(\.interval)
            return [
                "date": MCPDate.day(day),
                "working_hours": workday.map { ["start": MCPDate.time($0.start), "end": MCPDate.time($0.end)] } ?? NSNull(),
                "free_minutes": workday.map { Int(SlotFinder.freeDuration(in: $0, busy: busy) / 60) } ?? 0,
                "events": dayEvents.map { event in
                    ["title": event.title, "start": MCPDate.string(event.start), "end": MCPDate.string(event.end), "all_day": event.isAllDay, "read_only": true]
                },
                "blocks": dayBlocks.map(json),
                "drafts": drafts.filter { onDay($0.start) }.map(json),
            ]
        }
        return ["calendar_access": calendarService.hasAccess, "days": days]
    }

    private func scheduleTask(_ arguments: ToolArguments) throws -> [String: Any] {
        let task = try existingTask(arguments.requiredUUID("task_id"))
        let desired = try arguments.requiredDate("start")
        let duration = try lengthMinutes(arguments, task: task) * 60
        guard calendarService.hasAccess else { throw CalendarWriteError.notAuthorized }
        guard let workday = settingsStore.settings.workday(containing: desired) else {
            throw ToolError("\(MCPDate.day(desired)) has no working hours")
        }
        guard let start = SlotFinder.nextFreeStart(from: desired, duration: duration, busy: calendarService.busyIntervals(on: desired), workday: workday) else {
            throw ToolError("no free slot of \(Int(duration / 60)) minutes from \(MCPDate.time(desired)) until the end of the working day on \(MCPDate.day(desired))")
        }
        let block = try calendarService.insertBlock(for: task, start: start, end: start.addingTimeInterval(duration))
        return ["block": json(block), "moved": start != desired, "task": json(task)]
    }

    private func updateBlock(_ arguments: ToolArguments) throws -> [String: Any] {
        let block = try existingBlock(arguments.requiredUUID("id"))
        let start = try arguments.date("start")
        let length = try arguments.int("length_minutes")
        guard start != nil || length != nil else { throw ToolError("give start, length_minutes or both") }
        if let length, length <= 0 { throw ToolError("length_minutes must be positive") }
        let newStart = start ?? block.start
        let newEnd = newStart.addingTimeInterval(length.map { TimeInterval($0 * 60) } ?? block.end.timeIntervalSince(block.start))
        try calendarService.updateBlock(block, start: newStart, end: newEnd)
        return ["block": json(block)]
    }

    private func deleteBlock(_ arguments: ToolArguments) throws -> [String: Any] {
        let block = try existingBlock(arguments.requiredUUID("id"))
        guard try arguments.bool("confirm") == true else {
            return ["requires_confirmation": true, "would_delete": ["block": json(block)]]
        }
        let summary = json(block)
        try calendarService.removeBlock(block)
        return ["deleted": ["block": summary]]
    }

    private func proposeBlocks(_ arguments: ToolArguments) throws -> [String: Any] {
        let items = try arguments.objects("items")
        guard calendarService.hasAccess else { throw ToolError("calendar access is required to check proposals against events") }
        var accepted: [(index: Int, task: PlannerTask, interval: DateInterval)] = []
        var rejected: [[String: Any]] = []
        for (index, item) in items.enumerated() {
            let itemArguments = ToolArguments(item)
            do {
                let task = try existingTask(itemArguments.requiredUUID("task_id"))
                let start = try itemArguments.requiredDate("start")
                let interval = DateInterval(start: start, duration: try lengthMinutes(itemArguments, task: task) * 60)
                guard let workday = settingsStore.settings.workday(containing: start),
                      interval.start >= workday.start, interval.end <= workday.end else {
                    throw ToolError("outside the working hours")
                }
                guard calendarService.isFree(interval) else { throw ToolError("overlaps a calendar event or a block") }
                if let other = accepted.first(where: { $0.interval.start < interval.end && $0.interval.end > interval.start }) {
                    throw ToolError("overlaps item \(other.index) of this proposal")
                }
                accepted.append((index, task, interval))
            } catch let error as ToolError {
                rejected.append(["index": index, "task_id": item["task_id"] ?? NSNull(), "reason": error.message])
            }
        }
        let drafts = try calendarService.replaceDrafts(with: accepted.map { ($0.task, $0.interval) })
        return [
            "proposal_id": drafts.first?.proposalID.map { $0.uuidString.lowercased() } ?? NSNull(),
            "drafts": zip(accepted, drafts).map { item, draft in json(draft).merging(["index": item.index]) { $1 } },
            "rejected": rejected,
        ]
    }

    // MARK: Time entries

    private func listTimeEntries(_ arguments: ToolArguments) throws -> [String: Any] {
        let calendar = Calendar.planner
        let from = try calendar.startOfDay(for: arguments.requiredDate("from"))
        let to = try calendar.startOfDay(for: arguments.date("to") ?? from)
        guard to >= from else { throw ToolError("to must not be before from") }
        guard let end = calendar.date(byAdding: .day, value: 1, to: to) else { throw ToolError("invalid date range") }
        let descriptor = FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.start >= from && $0.start < end }, sortBy: [SortDescriptor(\.start)])
        let now = Date.now
        let entries: [[String: Any]] = try context.fetch(descriptor).map { entry in
            let task = entry.task
            return [
                "id": entry.id.uuidString.lowercased(),
                "start": MCPDate.string(entry.start),
                "end": entry.end.map(MCPDate.string) ?? NSNull(),
                "running": entry.end == nil,
                "minutes": entry.minutes(now: now),
                "task_id": task.map { $0.id.uuidString.lowercased() } ?? NSNull(),
                "title": task?.title ?? "",
                "project": task?.project?.name ?? NSNull(),
                "source": task?.sourceLabel ?? NSNull(),
                "external_ref": task.map(externalRefJSON) ?? NSNull(),
            ]
        }
        return ["from": MCPDate.day(from), "to": MCPDate.day(to), "entries": entries]
    }

    /// `length_minutes`, or the default block length for the task (its estimate or the setting).
    private func lengthMinutes(_ arguments: ToolArguments, task: PlannerTask) throws -> TimeInterval {
        let minutes = try arguments.int("length_minutes") ?? settingsStore.settings.blockMinutes(for: task)
        guard minutes > 0 else { throw ToolError("length_minutes must be positive") }
        return TimeInterval(minutes)
    }

    // MARK: JSON

    private func json(_ project: Project) -> [String: Any] {
        ["id": project.id.uuidString.lowercased(), "name": project.name, "color": project.colorIndex, "open_tasks": project.tasks.count(where: \.isOpen)]
    }

    private func json(_ task: PlannerTask) -> [String: Any] {
        let scheduled: Any = task.nextBlock.map { $0.start < Calendar.planner.startOfDay(for: .now).addingTimeInterval(86_400) ? "today" : "later" } ?? NSNull()
        return [
            "id": task.id.uuidString.lowercased(),
            "title": task.title,
            "project": task.project?.name ?? NSNull(),
            "project_id": task.project.map { $0.id.uuidString.lowercased() } ?? NSNull(),
            "urgency": task.urgency,
            "estimate_hours": task.estimateMinutes.map { Double($0) / 60 } ?? NSNull(),
            "due_date": task.dueDate.map(MCPDate.day) ?? NSNull(),
            "status": Self.statusName(task.status),
            "notes": task.notes,
            "source": task.sourceLabel ?? NSNull(),
            "external_ref": externalRefJSON(task),
            "blocks": task.confirmedBlocks.sorted { $0.start < $1.start }.map { ["id": $0.id.uuidString.lowercased(), "start": MCPDate.string($0.start), "end": MCPDate.string($0.end)] },
            "drafts": task.blocks.filter(\.isDraft).sorted { $0.start < $1.start }.map { ["id": $0.id.uuidString.lowercased(), "start": MCPDate.string($0.start), "end": MCPDate.string($0.end)] },
            "scheduled": scheduled,
            "created_at": MCPDate.string(task.createdAt),
        ]
    }

    private func externalRefJSON(_ task: PlannerTask) -> Any {
        task.externalRefLabel.map { label in
            ["label": label, "id": task.externalRefID ?? NSNull(), "url": task.externalRefURL ?? NSNull()] as [String: Any]
        } ?? NSNull()
    }

    private func json(_ block: Block) -> [String: Any] {
        [
            "id": block.id.uuidString.lowercased(),
            "state": block.state.rawValue,
            "task_id": block.task.map { $0.id.uuidString.lowercased() } ?? NSNull(),
            "title": block.task?.title ?? "",
            "project": block.task?.project?.name ?? NSNull(),
            "start": MCPDate.string(block.start),
            "end": MCPDate.string(block.end),
            "proposal_id": block.proposalID.map { $0.uuidString.lowercased() } ?? NSNull(),
        ]
    }

    private static let statusNames: [TaskStatus: String] = [.todo: "todo", .inProgress: "in_progress", .waiting: "waiting", .done: "done"]

    static func statusName(_ status: TaskStatus) -> String { statusNames[status] ?? status.rawValue }

    static func status(_ name: String) throws -> TaskStatus {
        guard let status = statusNames.first(where: { $0.value == name })?.key else {
            throw ToolError("status must be one of: todo, in_progress, waiting, done")
        }
        return status
    }
}

struct ExternalRef {
    let label: String
    let id: String?
    let url: String?
}

/// Optional task fields shared by `create_task` and `update_task`. An outer `nil` means "not given"; an inner
/// `nil` means "clear" (the argument was JSON `null`).
private struct TaskFields {
    var projectReference: String??
    var urgency: Int?
    var estimateMinutes: Int??
    var dueDate: Date??
    var status: TaskStatus?
    var notes: String??
    var source: String??
    var externalRef: ExternalRef??

    @MainActor
    init(_ arguments: ToolArguments) throws {
        projectReference = try arguments.nullable("project") { try arguments.string("project") }
        urgency = try arguments.int("urgency")
        if let urgency, !(0...3).contains(urgency) { throw ToolError("urgency must be between 0 and 3") }
        estimateMinutes = try arguments.nullable("estimate_hours") {
            guard let hours = try arguments.double("estimate_hours"), hours > 0 else { throw ToolError("estimate_hours must be positive") }
            return Int((hours * 60).rounded())
        }
        dueDate = try arguments.nullable("due_date") { try arguments.date("due_date").map { Calendar.planner.startOfDay(for: $0) } }
        status = try arguments.string("status").map(MCPTools.status)
        notes = try arguments.nullable("notes") { try arguments.string("notes") }
        source = try arguments.nullable("source") { try arguments.string("source") }
        externalRef = try arguments.nullable("external_ref") {
            guard let object = try arguments.object("external_ref") else { return nil }
            let reference = ToolArguments(object)
            return ExternalRef(label: try reference.requiredString("label"), id: try reference.string("id"), url: try reference.string("url"))
        }
    }

    /// Applies every given field except the project and a transition to done, which the callers handle.
    func apply(to task: PlannerTask) {
        if let urgency { task.urgency = urgency }
        if let estimateMinutes { task.estimateMinutes = estimateMinutes }
        if let dueDate { task.dueDate = dueDate }
        if let status, status != .done || task.status == .done { task.status = status }
        if let notes { task.notes = notes ?? "" }
        if let source { task.sourceLabel = source }
        if let externalRef {
            task.externalRefLabel = externalRef?.label
            task.externalRefID = externalRef?.id
            task.externalRefURL = externalRef?.url
        }
    }
}

/// Typed access to tool arguments; type mismatches name the argument.
@MainActor
struct ToolArguments {
    let values: [String: Any]

    init(_ values: [String: Any]) {
        self.values = values
    }

    private func value(_ key: String) -> Any? {
        values[key].flatMap { $0 is NSNull ? nil : $0 }
    }

    /// `nil` when the key is absent, `.some(nil)` when it is JSON `null`, otherwise the parsed value.
    func nullable<Value>(_ key: String, parse: () throws -> Value?) throws -> Value?? {
        guard let raw = values[key] else { return nil }
        if raw is NSNull { return .some(nil) }
        return .some(try parse())
    }

    func string(_ key: String) throws -> String? {
        guard let raw = value(key) else { return nil }
        guard let string = raw as? String else { throw ToolError("\(key) must be a string") }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func requiredString(_ key: String) throws -> String {
        guard let string = try string(key), !string.isEmpty else { throw ToolError("\(key) is required") }
        return string
    }

    func bool(_ key: String) throws -> Bool? {
        guard let raw = value(key) else { return nil }
        guard let number = raw as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { throw ToolError("\(key) must be true or false") }
        return number.boolValue
    }

    func double(_ key: String) throws -> Double? {
        guard let raw = value(key) else { return nil }
        guard let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { throw ToolError("\(key) must be a number") }
        return number.doubleValue
    }

    func int(_ key: String) throws -> Int? {
        guard let number = try double(key) else { return nil }
        guard number == number.rounded() else { throw ToolError("\(key) must be a whole number") }
        return Int(number)
    }

    func requiredUUID(_ key: String) throws -> UUID {
        let string = try requiredString(key)
        guard let id = UUID(uuidString: string) else { throw ToolError("\(key) is not a valid id: \(string)") }
        return id
    }

    func date(_ key: String) throws -> Date? {
        guard let string = try string(key) else { return nil }
        guard let date = MCPDate.parse(string) else {
            throw ToolError("\(key) must be an ISO 8601 date or date-time, e.g. 2026-10-15 or 2026-10-15T16:00")
        }
        return date
    }

    func requiredDate(_ key: String) throws -> Date {
        guard let date = try date(key) else { throw ToolError("\(key) is required") }
        return date
    }

    func object(_ key: String) throws -> [String: Any]? {
        guard let raw = value(key) else { return nil }
        guard let object = raw as? [String: Any] else { throw ToolError("\(key) must be an object") }
        return object
    }

    func objects(_ key: String) throws -> [[String: Any]] {
        guard let raw = value(key) else { throw ToolError("\(key) is required") }
        guard let objects = raw as? [[String: Any]] else { throw ToolError("\(key) must be a list of objects") }
        return objects
    }
}

/// Dates in the user's time zone: date-times with offset on output; with or without offset on input.
@MainActor
enum MCPDate {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let localFormatters: [DateFormatter] = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    static func parse(_ string: String) -> Date? {
        isoFormatter.date(from: string)
            ?? fractionalFormatter.date(from: string)
            ?? localFormatters.lazy.compactMap { $0.date(from: string) }.first
    }

    static func string(_ date: Date) -> String { isoFormatter.string(from: date) }

    /// "2026-10-15"
    static func day(_ date: Date) -> String { String(string(date).prefix(10)) }

    /// "08:00"
    static func time(_ date: Date) -> String { String(string(date).dropFirst(11).prefix(5)) }
}
