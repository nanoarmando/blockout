## Why

Completing a task deletes its blocks that have not started yet, and the blocks that remain look exactly like blocks of open tasks (every block shows a check mark) and can still be dragged. The user reviews the calendar to understand what they worked on during the week, so worked blocks must stay as an unmovable, recognizable record. A ticket also often needs more work after a first delivery (for example, client feedback next week), so future blocks must survive completion and adding work must bring the task back.

## What Changes

- **BREAKING:** completing a task keeps all its blocks and their calendar events, including future ones, which stay editable.
- Completing a task locks the blocks that have started by then (past and in progress, with their original range). Locked blocks stay locked even if the task is reopened; they cannot be moved or resized from the calendar or the MCP, but can be deleted.
- Creating a new block for a completed task (agendar sesión, dropping it on the calendar, MCP `schedule_task`, accepting a proposal) reopens the task to "Por hacer", without the "Reabierto" mark.
- Locked blocks use a "completed" style in every calendar view: project color with transparency, a dashed outline in the project color, and a check mark shown only on locked blocks. The legend gains "Completado".
- Locked blocks are not moved by the "+15 min" cascade; they keep counting as busy time.
- MCP: `update_block` rejects locked blocks; block output gains `locked`; descriptions reflect the new rules.
- Existing past blocks of completed tasks are locked once on upgrade.

## Capabilities

### New Capabilities
- `completed-task-blocks`: keeping blocks on completion, locking worked blocks, reopening on new blocks, the completed style, and the MCP contract.

### Modified Capabilities

None (`add-planner-core`, `add-mcp-server`, `add-time-tracking` and `add-schedule-session` are not archived yet; this change supersedes `add-planner-core`'s "Completed tasks keep their history" and `add-schedule-session`'s "Sessions on done tasks", which is updated to reopen the task).

## Impact

- Data model: one field on blocks (schema version 6, with a one-time pass for completed tasks).
- App: completion path, block creation path, time grid and month view, legend, drag and drop targets, resize, "+15 min" cascade.
- MCP: `update_block`, `schedule_task` result, block JSON, tool descriptions.
- Docs: `README.md` and `AGENTS.md`.
- Depends on `add-planner-core`, `add-mcp-server`, `add-time-tracking`, `add-agent-time-entries` (schema version 5) and `add-schedule-session`.
