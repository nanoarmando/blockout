## ADDED Requirements

### Requirement: Reopened mark set by agents
A task SHALL carry an optional reopened mark with the date and time it was set. `update_task` SHALL accept an optional boolean `reopened`: `true` SHALL set the mark to the current date and time (replacing an earlier one) when the task is open after the update, and SHALL be ignored when the task is done after the update; `false` or `null` SHALL remove the mark. Omitting `reopened` SHALL leave the mark unchanged. Reopening a task in the app (completion control or status buttons) SHALL NOT set the mark.

#### Scenario: Agent reopens a completed task
- **WHEN** an agent calls `update_task` on a done task with status `todo` and `reopened` true
- **THEN** the task becomes "Por hacer" and carries the reopened mark with the current date and time

#### Scenario: Flag sent with a done status
- **WHEN** an agent calls `update_task` with status `done` and `reopened` true
- **THEN** the task is completed and carries no reopened mark

#### Scenario: Manual reopen
- **WHEN** the user unchecks a completed task in the "Completadas" group
- **THEN** the task becomes "Por hacer" without the reopened mark

#### Scenario: Reopened again
- **WHEN** an agent sends `reopened` true for a task that already carries the mark
- **THEN** the mark date becomes the current date and time

### Requirement: Mark removed on completion
The reopened mark SHALL be removed when the task is completed by any path: the completion control in the list or the detail, the timer, or `update_task` with status `done`. Other status changes (En curso, Esperando, Por hacer) SHALL keep the mark.

#### Scenario: Completing a reopened task
- **WHEN** the user completes a task that carries the reopened mark
- **THEN** the task is done without the mark, and reopening it manually later shows no badge

#### Scenario: Starting a reopened task
- **WHEN** the user sets a reopened task to "En curso"
- **THEN** the task keeps the reopened mark

### Requirement: Reopened badge
While an open task carries the reopened mark, its row in the task list and its detail SHALL show a "Reabierto" badge, and hovering the badge SHALL show the date the mark was set.

#### Scenario: Badge in the list
- **WHEN** an agent reopens a task with `reopened` true
- **THEN** its row shows the "Reabierto" badge even when the task has no other metadata

#### Scenario: Badge date
- **WHEN** the user hovers the badge of a task reopened on 19/10/2026
- **THEN** the tooltip shows that date

### Requirement: Reopened filter
The sidebar SHALL offer a "Reabiertas" filter, placed after "Vencidas" and before "Completadas", with the count of open tasks that carry the reopened mark. Selecting it SHALL restrict the task list to those tasks.

#### Scenario: Filtering reopened tasks
- **WHEN** two open tasks carry the reopened mark and the user selects "Reabiertas"
- **THEN** the list shows only those two tasks and the filter count is 2

#### Scenario: Count after completion
- **WHEN** the user completes one of them
- **THEN** the "Reabiertas" count becomes 1

### Requirement: Reopened mark in tool output
Every task returned by an MCP tool SHALL include `reopened_at`, the date and time of the mark in the same format as other dates, or `null` when the task has no mark. The tool descriptions SHALL document `reopened` and `reopened_at`.

#### Scenario: Listing tasks
- **WHEN** an agent calls `list_tasks` and one task carries the mark
- **THEN** that task has `reopened_at` with the mark date and the others have `null`

#### Scenario: Older client
- **WHEN** an agent calls `update_task` without `reopened`
- **THEN** the call behaves exactly as before this change
