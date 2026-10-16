## Purpose

Records the real time spent on each task with little friction, keeps it editable, and makes it available to agents for time reports.

## ADDED Requirements

### Requirement: Start prompt
When a block starts and no timer is running for it, Blockout SHALL show a macOS notification "¿Estás trabajando en esto?" with the block title as shown in the calendar ("[Proyecto] Tarea") and block range and the actions "Sí, empezar", "En 5 min" and "Saltar". "Sí, empezar" SHALL start the timer for that task; "En 5 min" SHALL ask again five minutes later while the block is still in progress; "Saltar" SHALL not ask again for that block. Without notification permission, the prompt SHALL appear only in the menu bar menu, and the menu SHALL show "Notificaciones desactivadas" with "Abrir Ajustes", which opens the macOS notification settings. Permission granted later SHALL take effect without restarting the app.

#### Scenario: Accept at block start
- **WHEN** the 11:00 block of "Checkout - Personalizaciones por país" starts and the user chooses "Sí, empezar"
- **THEN** the timer starts for that task and the menu bar shows the elapsed time

#### Scenario: Snooze
- **WHEN** the user chooses "En 5 min" at 11:00
- **THEN** the notification appears again at 11:05 if the block is still in progress

#### Scenario: Notifications turned off
- **WHEN** notifications for Blockout are off in macOS and the user opens the menu bar menu
- **THEN** the menu shows "Notificaciones desactivadas" and "Abrir Ajustes"; after the user turns them on and returns to Blockout, the warning disappears and the next block start is notified

### Requirement: End prompt
When a block ends while the timer runs for its task, Blockout SHALL show a macOS notification "¿Terminaste esta tarea?" with the block title and block range and the actions "Terminada" and "+15 min". "Terminada" SHALL stop the timer and mark the task as done; "+15 min" SHALL extend the block as the menu's "+15 min" does, and the prompt SHALL move to the new end. No end prompt SHALL be shown for a block whose task is not being timed.

#### Scenario: Finish at block end
- **WHEN** the timer runs for "Checkout - Personalizaciones por país", its 11:00–12:00 block reaches 12:00 and the user chooses "Terminada"
- **THEN** the timer stops, the entry is saved and the task is marked as done

#### Scenario: Extend at block end
- **WHEN** the same block reaches 12:00 and the user chooses "+15 min"
- **THEN** the block ends at 12:15, the following blocks shift as with the menu action, and the prompt appears again at 12:15

#### Scenario: Task not being timed
- **WHEN** a block reaches its end and no timer runs for its task
- **THEN** no end prompt is shown

### Requirement: One timer at a time
Only one timer SHALL run at a time. Starting a timer for another task SHALL stop the current one and save its entry.

#### Scenario: Switch task
- **WHEN** a timer runs for task A and the user starts task B
- **THEN** A's entry is saved with the current time as its end and B's timer starts

### Requirement: Time entries
Each run of the timer between start and pause, stop or completion SHALL be saved as a time entry of the task with start and end. Pausing SHALL end the current entry; resuming SHALL start a new one. Entries SHALL be saved even if the app quits while the timer runs, ending at the quit time.

#### Scenario: Pause and resume
- **WHEN** the user works 11:00 to 11:20, pauses, and resumes at 11:30 until 11:50
- **THEN** the task has two entries: 11:00–11:20 and 11:30–11:50

### Requirement: Edit time in the task detail
The task detail SHALL list the task's entries with day, editable start and end, and duration, the total against the estimate, a delete control per entry, "+ Registro manual" to add an entry, and "Retomar cronómetro" to start the timer for the task. While the timer runs for the task, the detail SHALL say so and offer "Detener". An end earlier than its start SHALL be rejected.

#### Scenario: Correct an entry
- **WHEN** the user changes an entry's end from 11:42 to 11:55
- **THEN** its duration and the total update and the change is saved

#### Scenario: Invalid range
- **WHEN** the user sets an end before the start
- **THEN** the change is rejected and the previous value is kept

### Requirement: Time entries in the MCP
The MCP server SHALL provide `list_time_entries` with a date range, returning each entry's start, end, minutes, task id and title, project, source and external reference, ordered by start, so an agent can group them by day and by ticket.

#### Scenario: Last week's report
- **WHEN** an agent requests entries from Monday to Friday of last week
- **THEN** it receives every entry in that range with its task, project and Odoo reference when the task has one

### Requirement: No time view
Blockout SHALL NOT include a time-report view; recorded time is visible only per task and through the MCP.

#### Scenario: Looking for totals
- **WHEN** the user wants weekly totals
- **THEN** they are obtained by asking an agent, which reads `list_time_entries`
