## Why

External automations complete and reopen tasks through the MCP when their source item (for example, a ticket) leaves and later returns. Today a reopened task looks like any other open task, so the user does not notice that work they considered finished is back. A visible "Reabierto" mark, and a way to list those tasks, makes that return explicit.

## What Changes

- A task can carry a "reopened" mark with the date it was set. Only an agent sets it, through `update_task`; a manual reopen in the app does not.
- The task row and the task detail show a "Reabierto" badge while the mark is present. The mark is removed only when the task is completed, from any path (app, timer, MCP).
- New sidebar filter "Reabiertas" with its count: open tasks that carry the mark.
- MCP: `update_task` accepts an optional `reopened` boolean, and every task in tool output includes `reopened_at`. Both are additive; existing clients keep working.
- The author's external automation (separate repository) starts sending `reopened: true` when it reopens a task whose source item returned. Its rules live in that repository and ship as its own release after this one.

## Capabilities

### New Capabilities
- `task-reopening`: the reopened mark, its badge, its sidebar filter, its lifecycle and its MCP contract.

### Modified Capabilities

None (`add-planner-core` and `add-mcp-server` are not archived yet; this change only adds a capability that extends their sidebar filters and task tools).

## Impact

- Data model: one optional field on tasks (new schema version with a lightweight migration).
- App: completion path, sidebar filters, task row, task detail.
- MCP: `update_task` input and the task output of every tool; tool descriptions.
- Docs: `README.md` (filters, MCP) and `AGENTS.md` (schema version, MCP contract).
- Depends on `add-planner-core` and `add-mcp-server`.
