import Foundation
import SwiftData

enum BlockoutSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Project.self, PlannerTask.self, Block.self] }

    @Model
    final class Project {
        var id: UUID = UUID()
        /// Unique case-insensitively; enforced by `ModelContext.project(named:)`.
        var name: String = ""
        var colorIndex: Int = 0
        var createdAt: Date = Date()
        @Relationship(deleteRule: .nullify, inverse: \PlannerTask.project)
        var tasks: [PlannerTask] = []

        init(name: String, colorIndex: Int) {
            self.name = name
            self.colorIndex = colorIndex
        }
    }

    @Model
    final class PlannerTask {
        var id: UUID = UUID()
        var title: String = ""
        var project: Project?
        /// 0 none, 1 low (!), 2 medium (!!), 3 high (!!!).
        var urgency: Int = 0
        var estimateMinutes: Int?
        var dueDate: Date?
        var statusRaw: String = TaskStatus.todo.rawValue
        var notes: String = ""
        var sourceLabel: String?
        var externalRefLabel: String?
        var externalRefID: String?
        var externalRefURL: String?
        var createdAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \Block.task)
        var blocks: [Block] = []

        init(title: String, project: Project? = nil, urgency: Int = 0, estimateMinutes: Int? = nil) {
            self.title = title
            self.project = project
            self.urgency = urgency
            self.estimateMinutes = estimateMinutes
        }
    }

    @Model
    final class Block {
        var id: UUID = UUID()
        var task: PlannerTask?
        var start: Date = Date()
        var end: Date = Date()
        /// EventKit identifier of the mirrored event; the event URL `blockout://block/<id>` is the fallback.
        var eventIdentifier: String?

        init(id: UUID, task: PlannerTask, start: Date, end: Date, eventIdentifier: String?) {
            self.id = id
            self.task = task
            self.start = start
            self.end = end
            self.eventIdentifier = eventIdentifier
        }
    }
}

enum BlockoutSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Project.self, PlannerTask.self, Block.self] }

    @Model
    final class Project {
        var id: UUID = UUID()
        /// Unique case-insensitively; enforced by `ModelContext.project(named:)`.
        var name: String = ""
        var colorIndex: Int = 0
        var createdAt: Date = Date()
        @Relationship(deleteRule: .nullify, inverse: \PlannerTask.project)
        var tasks: [PlannerTask] = []

        init(name: String, colorIndex: Int) {
            self.name = name
            self.colorIndex = colorIndex
        }
    }

    @Model
    final class PlannerTask {
        var id: UUID = UUID()
        var title: String = ""
        var project: Project?
        /// 0 none, 1 low (!), 2 medium (!!), 3 high (!!!).
        var urgency: Int = 0
        var estimateMinutes: Int?
        var dueDate: Date?
        var statusRaw: String = TaskStatus.todo.rawValue
        var notes: String = ""
        var sourceLabel: String?
        var externalRefLabel: String?
        var externalRefID: String?
        var externalRefURL: String?
        var createdAt: Date = Date()
        /// Confirmed blocks and drafts; use `confirmedBlocks` for anything that counts as scheduled time.
        @Relationship(deleteRule: .cascade, inverse: \Block.task)
        var blocks: [Block] = []

        init(title: String, project: Project? = nil, urgency: Int = 0, estimateMinutes: Int? = nil) {
            self.title = title
            self.project = project
            self.urgency = urgency
            self.estimateMinutes = estimateMinutes
        }
    }

    @Model
    final class Block {
        var id: UUID = UUID()
        var task: PlannerTask?
        var start: Date = Date()
        var end: Date = Date()
        /// EventKit identifier of the mirrored event; the event URL `blockout://block/<id>` is the fallback. Drafts have none.
        var eventIdentifier: String?
        /// `BlockState` raw value; blocks migrated from version 1 become confirmed.
        var stateRaw: String = BlockState.confirmed.rawValue
        /// The `propose_blocks` call that created a draft.
        var proposalID: UUID?

        init(id: UUID, task: PlannerTask, start: Date, end: Date, eventIdentifier: String?, state: BlockState = .confirmed, proposalID: UUID? = nil) {
            self.id = id
            self.task = task
            self.start = start
            self.end = end
            self.eventIdentifier = eventIdentifier
            self.stateRaw = state.rawValue
            self.proposalID = proposalID
        }
    }
}

enum BlockoutSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] { [Project.self, PlannerTask.self, Block.self, TimeEntry.self] }

    @Model
    final class Project {
        var id: UUID = UUID()
        /// Unique case-insensitively; enforced by `ModelContext.project(named:)`.
        var name: String = ""
        var colorIndex: Int = 0
        var createdAt: Date = Date()
        @Relationship(deleteRule: .nullify, inverse: \PlannerTask.project)
        var tasks: [PlannerTask] = []

        init(name: String, colorIndex: Int) {
            self.name = name
            self.colorIndex = colorIndex
        }
    }

    @Model
    final class PlannerTask {
        var id: UUID = UUID()
        var title: String = ""
        var project: Project?
        /// 0 none, 1 low (!), 2 medium (!!), 3 high (!!!).
        var urgency: Int = 0
        var estimateMinutes: Int?
        var dueDate: Date?
        var statusRaw: String = TaskStatus.todo.rawValue
        var notes: String = ""
        var sourceLabel: String?
        var externalRefLabel: String?
        var externalRefID: String?
        var externalRefURL: String?
        var createdAt: Date = Date()
        /// Confirmed blocks and drafts; use `confirmedBlocks` for anything that counts as scheduled time.
        @Relationship(deleteRule: .cascade, inverse: \Block.task)
        var blocks: [Block] = []
        @Relationship(deleteRule: .cascade, inverse: \TimeEntry.task)
        var timeEntries: [TimeEntry] = []

        init(title: String, project: Project? = nil, urgency: Int = 0, estimateMinutes: Int? = nil) {
            self.title = title
            self.project = project
            self.urgency = urgency
            self.estimateMinutes = estimateMinutes
        }
    }

    @Model
    final class Block {
        var id: UUID = UUID()
        var task: PlannerTask?
        var start: Date = Date()
        var end: Date = Date()
        /// EventKit identifier of the mirrored event; the event URL `blockout://block/<id>` is the fallback. Drafts have none.
        var eventIdentifier: String?
        /// `BlockState` raw value; blocks migrated from version 1 become confirmed.
        var stateRaw: String = BlockState.confirmed.rawValue
        /// The `propose_blocks` call that created a draft.
        var proposalID: UUID?

        init(id: UUID, task: PlannerTask, start: Date, end: Date, eventIdentifier: String?, state: BlockState = .confirmed, proposalID: UUID? = nil) {
            self.id = id
            self.task = task
            self.start = start
            self.end = end
            self.eventIdentifier = eventIdentifier
            self.stateRaw = state.rawValue
            self.proposalID = proposalID
        }
    }

    /// One run of the timer. A running entry has no end; at most one exists (enforced by `TimeTracker`).
    @Model
    final class TimeEntry {
        var id: UUID = UUID()
        var task: PlannerTask?
        var start: Date = Date()
        var end: Date?

        init(task: PlannerTask, start: Date, end: Date? = nil) {
            self.task = task
            self.start = start
            self.end = end
        }
    }
}

enum BlockoutMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BlockoutSchemaV1.self, BlockoutSchemaV2.self, BlockoutSchemaV3.self] }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: BlockoutSchemaV1.self, toVersion: BlockoutSchemaV2.self),
            .lightweight(fromVersion: BlockoutSchemaV2.self, toVersion: BlockoutSchemaV3.self),
        ]
    }
}

typealias Project = BlockoutSchemaV3.Project
typealias PlannerTask = BlockoutSchemaV3.PlannerTask
typealias Block = BlockoutSchemaV3.Block
typealias TimeEntry = BlockoutSchemaV3.TimeEntry

/// A draft is a block proposed through the MCP: it has no calendar event and does not count as scheduled time.
enum BlockState: String {
    case draft, confirmed
}

enum TaskStatus: String, CaseIterable, Identifiable {
    case todo, inProgress, waiting, done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .todo: "Por hacer"
        case .inProgress: "En curso"
        case .waiting: "Esperando"
        case .done: "Hecha"
        }
    }
}

enum BlockoutStore {
    static func makeContainer() throws -> ModelContainer {
        // BLOCKOUT_STORE_DIR isolates test runs; URL.applicationSupportDirectory ignores a redirected HOME
        let directory = ProcessInfo.processInfo.environment["BLOCKOUT_STORE_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
            ?? URL.applicationSupportDirectory.appending(path: "Blockout", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: BlockoutSchemaV3.self)
        let configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "Blockout.store"))
        return try ModelContainer(for: schema, migrationPlan: BlockoutMigrationPlan.self, configurations: configuration)
    }
}
