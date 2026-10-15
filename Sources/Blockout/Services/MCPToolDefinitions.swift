import Foundation

/// `tools/list`: names, descriptions and JSON input schemas of the tools in `MCPTools`.
extension MCPTools {
    static let definitions: [[String: Any]] = [
        tool(
            "list_projects",
            "List all projects with id, name, color (palette index 0-7) and open_tasks (number of tasks not done).",
            properties: [:]
        ),
        tool(
            "create_project",
            "Create a project. If a project with the same name exists (case-insensitive), it is returned instead (created: false).",
            properties: [
                "name": string("Project name, e.g. a client name."),
                "color": ["type": "integer", "minimum": 0, "maximum": 7, "description": "Palette index; assigned in rotation when omitted."],
            ],
            required: ["name"]
        ),
        tool(
            "list_tasks",
            "List tasks, newest first. By default only open tasks (not done). Each task has id, title, project, urgency (0 none to 3 high), estimate_hours, due_date (YYYY-MM-DD), status, notes, source, external_ref {label, id, url}, blocks and drafts with start and end, and scheduled (\"today\", \"later\" or null).",
            properties: [
                "status": statusSchema,
                "project": string("Project id or name (case-insensitive)."),
                "include_done": ["type": "boolean", "description": "Include done tasks. Default false."],
            ]
        ),
        tool(
            "create_task",
            "Create a task with native fields; never encode project, urgency or estimate in the title. Returns the existing task instead (created: false, duplicate_by) when an open task has the same title (case-insensitive) or any task, including done ones, has the same external_ref label and id, unless allow_duplicate is true.",
            properties: taskProperties.merging([
                "title": string("Task title without prefixes or suffixes."),
                "allow_duplicate": ["type": "boolean", "description": "Create even when a duplicate exists. Default false."],
            ]) { $1 },
            required: ["title"]
        ),
        tool(
            "update_task",
            "Update fields of a task. Only the given fields change; pass null to clear project, estimate_hours, due_date, notes, source or external_ref. Setting status to done follows the app rule: blocks that have not started yet are deleted with their calendar events.",
            properties: taskProperties.merging([
                "id": string("Task id."),
                "title": string("New title."),
            ]) { $1 },
            required: ["id"]
        ),
        tool(
            "delete_task",
            "Delete a task with its blocks and their calendar events. Without confirm: true nothing is deleted and the response lists what would be deleted with requires_confirmation: true.",
            properties: ["id": string("Task id."), "confirm": confirmSchema],
            required: ["id"]
        ),
        tool(
            "get_schedule",
            "Calendar for up to 31 days from a date: per day the working hours (null on weekends), read-only calendar events, blocks, draft blocks and free_minutes (working time not covered by events or blocks; drafts do not reduce it).",
            properties: [
                "from": string("First day, YYYY-MM-DD. Default today."),
                "days": ["type": "integer", "minimum": 1, "maximum": 31, "description": "Number of days. Default 1."],
            ]
        ),
        tool(
            "schedule_task",
            "Create a block for a task and write its busy event to the calendar immediately, like dragging the task to the calendar: if the start is taken, the block moves to the next free slot of that day within working hours (moved: true). Fails when nothing fits. Use propose_blocks instead when the user should review the plan first.",
            properties: [
                "task_id": string("Task id."),
                "start": dateTime("Desired start."),
                "length_minutes": lengthSchema,
            ],
            required: ["task_id", "start"]
        ),
        tool(
            "update_block",
            "Move or resize a block (or a draft). Moving an existing block may overlap other items, as in the app. The calendar event is updated.",
            properties: [
                "id": string("Block id."),
                "start": dateTime("New start."),
                "length_minutes": ["type": "integer", "minimum": 1, "description": "New length in minutes."],
            ],
            required: ["id"]
        ),
        tool(
            "delete_block",
            "Delete a block and its calendar event (or a draft). Without confirm: true nothing is deleted and the response shows the block with requires_confirmation: true.",
            properties: ["id": string("Block id."), "confirm": confirmSchema],
            required: ["id"]
        ),
        tool(
            "propose_blocks",
            "Propose a plan as draft blocks for the user to review in Blockout; nothing is written to the calendar until the user accepts. Each item becomes a draft when it fits inside working hours without overlapping events, blocks or earlier items of the same proposal; other items are rejected individually with a reason. A new proposal replaces all previous drafts (an empty list clears them).",
            properties: [
                "items": [
                    "type": "array",
                    "description": "Blocks to propose.",
                    "items": [
                        "type": "object",
                        "properties": ["task_id": string("Task id."), "start": dateTime("Start."), "length_minutes": lengthSchema],
                        "required": ["task_id", "start"],
                    ],
                ],
            ],
            required: ["items"]
        ),
        tool(
            "list_time_entries",
            "List the time entries recorded with the timer or by hand whose start falls between two days (inclusive), ordered by start, for time reports grouped by day and ticket. Each entry has id, start, end (null while the timer runs), running, minutes, task_id, title, project, source and external_ref {label, id, url}.",
            properties: [
                "from": string("First day, YYYY-MM-DD."),
                "to": string("Last day, YYYY-MM-DD, inclusive. Default: the same as from."),
            ],
            required: ["from"]
        ),
    ]

    private static func tool(_ name: String, _ description: String, properties: [String: Any], required: [String] = []) -> [String: Any] {
        ["name": name, "description": description, "inputSchema": ["type": "object", "properties": properties, "required": required]]
    }

    private static func string(_ description: String) -> [String: Any] {
        ["type": "string", "description": description]
    }

    private static func dateTime(_ description: String) -> [String: Any] {
        string("\(description) ISO 8601 in local time (2026-10-15T16:00) or with offset.")
    }

    private static let statusSchema: [String: Any] = ["type": "string", "enum": ["todo", "in_progress", "waiting", "done"], "description": "Task status."]
    private static let confirmSchema: [String: Any] = ["type": "boolean", "description": "Must be true to delete."]
    private static let lengthSchema: [String: Any] = [
        "type": "integer", "minimum": 1,
        "description": "Length in minutes. Default: the block length from settings (30 or 60 minutes, or the task estimate when set to follow the estimate).",
    ]

    private static let taskProperties: [String: Any] = [
        "project": ["type": ["string", "null"], "description": "Project id or name; a new name creates the project, an existing name is reused case-insensitively."],
        "urgency": ["type": "integer", "minimum": 0, "maximum": 3, "description": "0 none, 1 low, 2 medium, 3 high."],
        "estimate_hours": ["type": ["number", "null"], "description": "Estimated effort in hours, e.g. 1.5."],
        "due_date": ["type": ["string", "null"], "description": "Due date, YYYY-MM-DD."],
        "status": statusSchema,
        "notes": ["type": ["string", "null"], "description": "Free-text notes."],
        "source": ["type": ["string", "null"], "description": "Where the task came from, e.g. \"Reunión\" or \"Odoo\"."],
        "external_ref": [
            "type": ["object", "null"],
            "description": "Reference to the task in another system; label and id identify it for duplicate detection.",
            "properties": [
                "label": string("Display label, e.g. \"Odoo #8896\"."),
                "id": string("Identifier in the other system, e.g. \"8896\"."),
                "url": string("Link to the item."),
            ],
            "required": ["label"],
        ],
    ]
}
