## ADDED Requirements

### Requirement: Completion keeps every block
Completing a task, from any path (list, detail, menu bar timer, MCP), SHALL keep all its blocks and their calendar events, including blocks that have not started yet. This replaces the rule that deleted blocks that had not started. Blocks that have not started SHALL stay editable.

#### Scenario: Finish a first delivery
- **WHEN** the user completes a task at 11:00 that also has a block next Tuesday
- **THEN** next Tuesday's block and its calendar event remain and can still be moved

### Requirement: Completion locks worked blocks
Completing a task SHALL lock every block of the task that has started by that moment (past blocks and the block in progress), keeping their original time range. A locked block SHALL stay locked when the task is reopened. Blocks that had not started and blocks created later SHALL NOT be locked.

#### Scenario: Complete during a block
- **WHEN** the user completes a task at 11:00 during its 10:00–12:00 block, after a block yesterday
- **THEN** yesterday's block and the 10:00–12:00 block are locked with their times unchanged

#### Scenario: Reopen keeps history locked
- **WHEN** the user reopens a completed task with two locked blocks
- **THEN** both blocks stay locked

### Requirement: New blocks reopen completed tasks
Creating a new block for a completed task, from any path ("+ Agendar sesión", dropping the task on the calendar, MCP `schedule_task`, accepting a proposed block), SHALL reopen the task to "Por hacer" without the "Reabierto" mark. Moving or resizing an existing block SHALL NOT change the task's status.

#### Scenario: Client feedback
- **WHEN** the user chooses "+ Agendar sesión" on a completed task
- **THEN** a new editable block is created, the task becomes "Por hacer" without the "Reabierto" badge, and its earlier locked blocks stay locked

#### Scenario: Agent schedules a completed task
- **WHEN** an agent calls `schedule_task` for a completed task
- **THEN** the block is created and the task's status is "todo" in the result

### Requirement: Locked blocks cannot be moved or resized
A locked block SHALL NOT be draggable, resizable, or copyable with Option-drag in the calendar, and dropping a stale drag of it on the calendar or the task list SHALL do nothing. The MCP `update_block` SHALL reject a locked block with an error and change nothing. Deleting a locked block from the task detail or with `delete_block` SHALL remain possible. Changes made to its event outside Blockout SHALL still be reflected, as for any block.

#### Scenario: Drag attempt
- **WHEN** the user tries to drag or resize a locked block
- **THEN** nothing moves and the block keeps its time

#### Scenario: Agent move
- **WHEN** an agent calls `update_block` on a locked block
- **THEN** the call fails saying the block is locked and nothing changes

#### Scenario: Delete
- **WHEN** the user removes a locked block from the task detail
- **THEN** the block and its calendar event are deleted

### Requirement: Completed style
Locked blocks SHALL be drawn with the project color at reduced opacity, a dashed outline in the project color, and a check mark before the title, in the day, multi-day and week views; the month view SHALL show them with reduced opacity and the check mark. Unlocked blocks SHALL NOT show the check mark. The calendar legend SHALL include a "Completado" entry with this style.

#### Scenario: Mixed day
- **WHEN** a day has a block of an open task and a locked block
- **THEN** only the locked block is translucent with a dashed outline and a check mark

### Requirement: Locked blocks in scheduling
Locked blocks SHALL keep counting as busy time for free-slot search and free-time totals. The "+15 min" cascade SHALL NOT move or delete locked blocks; they stay in place even if the extended block overlaps them.

#### Scenario: Extension before a locked block
- **WHEN** the user extends a running block by 15 minutes and a locked block starts right after it
- **THEN** the locked block keeps its time

### Requirement: Lock in MCP output
Every block in MCP output SHALL include `locked` (true or false). Tool descriptions SHALL state that completing a task keeps its blocks and locks the started ones, that `update_block` rejects locked blocks, and that scheduling a completed task reopens it.

#### Scenario: Schedule of a day
- **WHEN** an agent reads the schedule of a day with a locked block
- **THEN** that block has `locked: true` and other blocks have `locked: false`

### Requirement: Existing completed tasks
When the store is upgraded to this version, every block of an already completed task that started before the upgrade SHALL be locked once.

#### Scenario: Upgrade
- **WHEN** the user installs this version with a completed task that has two past blocks
- **THEN** both blocks show the completed style and cannot be moved
