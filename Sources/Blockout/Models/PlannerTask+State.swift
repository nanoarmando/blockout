import Foundation
import SwiftData

extension PlannerTask {
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    var isOpen: Bool { status != .done }

    /// Title of the task's blocks and their calendar events; the task title itself never carries the prefix.
    var blockTitle: String {
        project.map { "[\($0.name)] \(title)" } ?? title
    }

    var confirmedBlocks: [Block] { blocks.filter { !$0.isDraft } }

    /// The first block that ends today or later; a task with one is "Agendada".
    var nextBlock: Block? {
        let startOfToday = Calendar.planner.startOfDay(for: .now)
        return confirmedBlocks.filter { $0.end > startOfToday }.min { $0.start < $1.start }
    }

    var isScheduled: Bool { nextBlock != nil }

    var scheduledMinutes: Int {
        confirmedBlocks.reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
    }

    var isOverdue: Bool {
        guard isOpen, let dueDate else { return false }
        return dueDate < Calendar.planner.startOfDay(for: .now)
    }

    var isForToday: Bool {
        let calendar = Calendar.planner
        if let dueDate, calendar.isDateInToday(dueDate) { return true }
        return confirmedBlocks.contains { calendar.isDateInToday($0.start) }
    }

    /// The label shown where the list and detail mention where the task came from.
    var originLabel: String? { externalRefLabel ?? sourceLabel }

    var externalURL: URL? { externalRefURL.flatMap(URL.init(string:)) }
}

extension ModelContext {
    /// Returns the project whose name matches case-insensitively, creating it when none exists.
    func project(named rawName: String) throws -> Project? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let projects = try fetch(FetchDescriptor<Project>())
        if let existing = projects.first(where: { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }) {
            return existing
        }
        let project = Project(name: name, colorIndex: projects.count % ProjectPalette.count)
        insert(project)
        try save()
        return project
    }

    func createTask(from entry: QuickEntry, projects: [Project]) throws {
        let project = entry.projectName.flatMap { name in projects.first { $0.name == name } }
        insert(PlannerTask(title: entry.title, project: project, urgency: entry.urgency, estimateMinutes: entry.estimateMinutes))
        try save()
    }
}

extension Block {
    var state: BlockState { BlockState(rawValue: stateRaw) ?? .confirmed }
    var isDraft: Bool { state == .draft }
}
