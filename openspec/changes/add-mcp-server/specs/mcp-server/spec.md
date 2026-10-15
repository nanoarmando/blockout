## Purpose

Gives AI agents and local automations a stable, local-only interface to read and change Blockout's projects, tasks, schedule and blocks using the Model Context Protocol.

## ADDED Requirements

### Requirement: Local transport
While enabled, Blockout SHALL serve MCP over HTTP JSON-RPC at `http://127.0.0.1:<port>/mcp` (port 43219 by default, configurable), listening only on the loopback interface. Each `tools/call` request SHALL work without a prior `initialize` or session header. When Blockout is not running, the server SHALL NOT be reachable.

#### Scenario: Stateless call
- **WHEN** a client posts a single `tools/call` for `list_tasks` without initializing
- **THEN** the server answers with the task list

#### Scenario: Remote access attempt
- **WHEN** another machine on the network tries to connect to the port
- **THEN** the connection is refused

### Requirement: Server settings
Settings SHALL show the server state (active, off, or port busy), its address with a copy button, and a switch to turn it off. If the port is busy, the server SHALL report it in settings and the rest of the app SHALL keep working.

#### Scenario: Port in use
- **WHEN** port 43219 is taken by another process
- **THEN** settings show "Puerto ocupado" and let the user choose another port

### Requirement: Project tools
The server SHALL provide `list_projects` (id, name, color, open-task count) and `create_project` (name, optional color), where creating an existing name (case-insensitive) SHALL return the existing project instead of a duplicate.

#### Scenario: Create existing project
- **WHEN** an agent calls `create_project` with "acme" and "Acme" exists
- **THEN** the result is the existing Acme project

### Requirement: Task tools
The server SHALL provide `list_tasks` (filters: status, project, include_done; each task with id, title, project, urgency 0–3, estimate in hours, due date, status, notes, source, external reference, blocks with start and end, and whether it is scheduled today or later), `create_task` and `update_task` covering every task field including the external reference, and `delete_task`. `create_task` SHALL return the existing task instead of creating a duplicate when an open task has the same title (case-insensitive) or when any task has the same external reference label and id, unless `allow_duplicate` is true.

#### Scenario: Native fields on create
- **WHEN** an agent creates "Checkout - Personalizaciones por país" with project Northwind, urgency 3, estimate 3, source "Odoo" and external reference {label "Odoo #8896", id "8896", url}
- **THEN** the task shows those fields natively and its title has no prefixes or suffixes

#### Scenario: Same external reference
- **WHEN** an agent creates a task with external reference "Odoo #8896" and a completed task already has it
- **THEN** the completed task is returned and no new task is created

### Requirement: Schedule and block tools
The server SHALL provide `get_schedule` (from date, up to 31 days: calendar events from the read calendars marked read-only, blocks, drafts, working hours and free time per day), `schedule_task` (task, start, optional length; creates a block and writes its calendar event immediately under the same rules as dragging), `update_block` (start and/or length) and `delete_block`.

#### Scenario: Schedule through MCP
- **WHEN** an agent calls `schedule_task` for a task at 16:00 for 60 minutes
- **THEN** the block appears in the app and the busy event exists in the destination calendar

### Requirement: Confirmation for destructive tools
`delete_task` and `delete_block` called without `confirm: true` SHALL NOT delete anything and SHALL return what would be deleted with `requires_confirmation: true`. With `confirm: true` they SHALL delete, including the calendar events of deleted blocks.

#### Scenario: Delete without confirmation
- **WHEN** an agent calls `delete_task` without `confirm`
- **THEN** nothing is deleted and the response lists the task and its blocks with `requires_confirmation: true`

### Requirement: Tool errors
Invalid arguments, unknown ids and calendar failures SHALL return an MCP tool error (`isError: true`) with a message that names the problem, and SHALL leave data unchanged.

#### Scenario: Unknown task
- **WHEN** an agent calls `update_task` with an id that does not exist
- **THEN** the call returns an error "task not found" and nothing changes
