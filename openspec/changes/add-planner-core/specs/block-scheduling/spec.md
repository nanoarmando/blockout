## Purpose

Turns tasks into time blocks on the calendar and keeps each block reserved as a busy event in the user's real calendar from the moment it is created.

## ADDED Requirements

### Requirement: Create a block by dragging a task
The user SHALL be able to drag a task from the list onto a time-based view. While dragging, a preview SHALL follow the pointer in 15-minute steps and show the resulting time range. The block length SHALL be the default block length from settings; the task estimate is only used when that setting is "según la estimación". When the preview overlaps an event or block, it SHALL move to the next free slot of that day; when no slot fits before the end of the working hours, the drop SHALL NOT be accepted.

#### Scenario: Drop on a free slot
- **WHEN** the user drops a task without estimate at 16:00 on Thursday and the default length is 60 minutes
- **THEN** a 16:00 to 17:00 block is created and the task moves to "Agendadas" showing "Jue 16:00"

#### Scenario: Drop over a meeting
- **WHEN** the user drops a 1-hour task at 13:45 and a meeting runs from 14:00 to 14:30
- **THEN** the preview and the block land at 14:30 to 15:30

#### Scenario: No room left
- **WHEN** the only free time left that day is 30 minutes and the task needs 1 hour
- **THEN** the preview is not shown for that day and dropping does nothing

### Requirement: Block is written to the calendar immediately
Creating a block SHALL immediately create an event in the destination calendar with the block title (`[Proyecto] Título` when the task has a project, otherwise the task title), the block's time range, the availability chosen in settings (busy by default) and a note identifying it as a Blockout block. The block SHALL NOT be created when the event cannot be saved, and the user SHALL see the reason.

#### Scenario: Busy for others
- **WHEN** the destination is a Google calendar added to macOS and the user creates a block
- **THEN** the event is saved at once as busy in that calendar, and macOS syncs it to Google so other people see the time as busy

#### Scenario: Destination not writable
- **WHEN** the destination calendar is read-only or missing
- **THEN** no block is created and the app asks the user to choose a writable destination calendar

### Requirement: Event titles follow the task
The task title SHALL stay as the user typed it; only block titles and their events carry the `[Proyecto] ` prefix. When a task's title or project changes, or its project is renamed, the events of all its blocks (past and future) SHALL be retitled, from the app or the MCP. Renaming an event outside Blockout SHALL NOT change the task. If an event cannot be updated, the task change SHALL be kept and the user SHALL see the reason.

#### Scenario: Block of a task with a project
- **WHEN** the user drags "Iterar catálogo" of project Northwind onto the calendar
- **THEN** the block and its calendar event are titled "[Northwind] Iterar catálogo" and the task keeps the title "Iterar catálogo"

#### Scenario: Project renamed
- **WHEN** the user renames the project "Acme" to "Acme Labs"
- **THEN** every event of that project's blocks, including past ones, is retitled "[Acme Labs] …"

#### Scenario: Task without project
- **WHEN** a task without project is scheduled
- **THEN** its event is titled with the task title alone

### Requirement: Move and resize blocks
The user SHALL be able to move a block to another time or day by dragging it and change its length by dragging its bottom edge, both in 15-minute steps. Moving or resizing an existing block SHALL be allowed even when it overlaps other items, because the user places it deliberately. The calendar event SHALL be updated at once.

#### Scenario: Move to Friday
- **WHEN** the user drags Thursday's 12:00 block to Friday 10:00
- **THEN** the block and its calendar event are at Friday 10:00 with the same length

### Requirement: Split a task into several blocks
Dragging a block while holding Option SHALL create an additional block for the same task, with its own calendar event, leaving the original in place.

#### Scenario: Three blocks for a 3-hour task
- **WHEN** the user Option-drags a 1-hour block of a 3h task twice to other days
- **THEN** the task has three blocks and the detail shows "3h de 3h agendada"

### Requirement: Unschedule a block
Dragging a block back onto the task list or removing it from the task detail SHALL delete the block and its calendar event. A task with no remaining block today or later SHALL return to "Sin agendar".

#### Scenario: Unschedule the only block
- **WHEN** the user drags a task's only block onto the list
- **THEN** the event disappears from the calendar and the task appears in "Sin agendar"

### Requirement: Completed tasks keep their history
Completing a task SHALL keep its past blocks and their events, and SHALL delete its blocks that have not started yet together with their events.

#### Scenario: Finish early
- **WHEN** the user completes a task that has a block tomorrow
- **THEN** tomorrow's block and event are deleted and past blocks remain
