## Why

The in-app timer runs one task at a time and depends on the user starting and stopping it, so it misses work done with AI agents: several agent sessions can run in parallel, a single session can move between tasks, and nobody remembers to start the timer. Agents already know what they are working on and when, so they should be able to record that time in Blockout directly, keeping Blockout as the single source for time reports.

## What Changes

- New MCP tool `upsert_time_entry`: an agent records a closed time entry (start and end) on a task, with a note and an origin, identified by a key chosen by the agent. Sending the same key again updates that entry (extends it, corrects its range, or moves it to another task) instead of creating a duplicate.
- New MCP tool `delete_time_entry`: an agent removes an entry by its key; requires `confirm: true` like the other delete tools.
- Time entries may overlap, including entries of the same task from parallel sessions; per-task totals keep summing every entry.
- `list_time_entries` adds `key`, `note` and `origin` to each entry. Existing fields are unchanged.
- The task detail shows each entry's note and origin under its time row when present.

## Capabilities

### New Capabilities
- `agent-time-entries`: agent-written time entries, their key-based upsert and delete, overlap rules, their extra fields in `list_time_entries` and in the task detail.

### Modified Capabilities

None (`add-time-tracking` and `add-mcp-server` are not archived yet; this change only adds a capability that extends their time entries and tools).

## Impact

- Data model: three optional fields on time entries (new schema version with a lightweight migration).
- MCP: two new tools, additive fields in `list_time_entries`, tool descriptions.
- App: task detail time rows.
- Docs: `README.md` (MCP tools) and `AGENTS.md` (schema version, time-tracking and MCP contracts).
- Depends on `add-time-tracking` and `add-mcp-server`.
