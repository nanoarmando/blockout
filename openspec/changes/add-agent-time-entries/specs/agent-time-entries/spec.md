## ADDED Requirements

### Requirement: Record time entries from agents
The MCP server SHALL provide `upsert_time_entry` with a required `key`, `task_id`, `start` and `end`, and optional `note` and `origin`. When no entry has that key, it SHALL create a closed time entry on the task with those values. The result SHALL include the entry and `created: true`.

#### Scenario: New entry
- **WHEN** an agent sends key "s1-1", task A, start 10:00, end 10:40, note "Theme fixes" and origin "Agent"
- **THEN** task A has a new entry 10:00–10:40 with that note and origin, and the result says `created: true`

### Requirement: Update an entry by key
When an entry with the given key exists, `upsert_time_entry` SHALL replace its task, start, end, note and origin with the values sent instead of creating a new entry, and the result SHALL say `created: false`. Omitted optional fields SHALL be cleared. Keys SHALL be unique across all entries.

#### Scenario: Extend a running session
- **WHEN** an entry with key "s1-1" covers 10:00–10:40 and the agent sends key "s1-1" with start 10:00 and end 11:00
- **THEN** the same entry now covers 10:00–11:00, no new entry exists, and the result says `created: false`

#### Scenario: Move to another task
- **WHEN** an entry with key "s1-1" belongs to task A and the agent sends key "s1-1" with task B
- **THEN** the entry belongs to task B and no longer counts in task A's total

### Requirement: Agent entries need a task and a closed range
`upsert_time_entry` SHALL reject a missing or unknown `task_id`, a missing `start` or `end`, an `end` earlier than `start`, and an empty `key`, returning an error that names the problem and changing nothing.

#### Scenario: Unknown task
- **WHEN** an agent sends a `task_id` that does not exist
- **THEN** the call fails with "task not found" and no entry is created or changed

#### Scenario: Invalid range
- **WHEN** an agent sends an end earlier than the start
- **THEN** the call fails and no entry is created or changed

### Requirement: Overlapping entries
Time entries SHALL be allowed to overlap, including entries of the same task. A task's recorded total SHALL be the sum of all its entries. Agent entries SHALL NOT affect the running timer.

#### Scenario: Parallel sessions on one task
- **WHEN** two agents each record 10:00–11:00 on task A with different keys
- **THEN** task A has both entries and its total is 2 hours

#### Scenario: Timer running
- **WHEN** the user's timer runs for task A and an agent records 10:00–10:30 on task B
- **THEN** the timer keeps running for task A and task B gains the entry

### Requirement: Delete an entry by key
The MCP server SHALL provide `delete_time_entry` with a required `key`. Without `confirm: true` it SHALL change nothing and return the entry that would be deleted with `requires_confirmation: true`. With `confirm: true` it SHALL delete the entry. An unknown key SHALL return an error and change nothing.

#### Scenario: Confirmed delete
- **WHEN** an agent sends key "s1-1" with `confirm: true`
- **THEN** the entry is deleted and no longer counts in its task's total

#### Scenario: Missing confirmation
- **WHEN** an agent sends key "s1-1" without `confirm`
- **THEN** nothing is deleted and the response shows the entry with `requires_confirmation: true`

### Requirement: Agent fields in list_time_entries
`list_time_entries` SHALL add `key`, `note` and `origin` to each entry, null when absent, keeping every existing field and its meaning unchanged.

#### Scenario: Mixed entries
- **WHEN** an agent lists a day with one timer entry and one agent entry
- **THEN** the timer entry has null `key`, `note` and `origin`, and the agent entry has the values it was recorded with

### Requirement: Note and origin in the task detail
The task detail SHALL show an entry's note and origin under its time row when present. Entries without them SHALL look as they do today.

#### Scenario: Agent entry in the detail
- **WHEN** the user opens a task with an agent entry noted "Theme fixes" from origin "Agent"
- **THEN** the entry's row shows "Theme fixes" and "Agent" under its start, end and duration
