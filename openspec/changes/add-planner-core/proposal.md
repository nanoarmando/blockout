## Why

Time-blocking apps such as Anchor keep tasks and the calendar apart: blocks are not written to the real calendar, so colleagues do not see the time as busy, and the data model lacks fields like urgency and estimate. Blockout is a free (GPL-3.0) native macOS planner where scheduling a task immediately reserves that time in the user's own calendar. This first stage delivers the planner itself, usable without any integration.

## What Changes

- New macOS app "Blockout" (SwiftUI, macOS 15+, local data only).
- Tasks and projects with native fields: title, project, urgency (none, `!`, `!!`, `!!!`), estimate, due date, status, notes, source label and optional external reference (shown, not edited, in this stage).
- Task list with one input that filters while typing and creates on Enter, detecting an existing project name in the text, a trailing estimate (`2h`) and urgency (`!`, `!!`, `!!!`).
- Sidebar filters (Todas, Hoy, Sin agendar, Agendadas, Vencidas), project list (first five plus "Ver más") and source filter.
- Calendar with Día, Días (2 to 7 days from today), Semana and Mes views, reading the macOS calendars the user selects; read-only events, project-colored blocks, free time per day and a red current-time line.
- Drag a task onto the calendar to create a block; move, resize, duplicate with Option and drag back to unschedule. Every block is written at once as a busy event in the destination calendar, and changes made in Calendar to those events are reflected back.
- Task detail with status, urgency, estimate, due date, blocks ("agendar las horas restantes") and notes.
- Settings: destination calendar, availability (busy or free), calendars that are read (picker with search, grouped by account), working hours and default block length. Light and dark appearance following the system.

## Capabilities

### New Capabilities
- `task-management`: tasks and projects, their fields, the list, filters, the quick filter-and-create input and task detail.
- `calendar-view`: day, days, week and month views of calendar events and blocks, navigation, free time and current-time line.
- `block-scheduling`: creating, moving, resizing, duplicating and removing blocks, the scheduled state of a task, and writing blocks to the destination calendar.
- `calendar-sources`: calendar access permission, choosing the calendars that are read, the destination calendar and two-way consistency with Calendar.
- `app-preferences`: working hours, default block length and appearance.

### Modified Capabilities

None (new project).

## Impact

- New repository `blockout` (Swift package app, GPL-3.0).
- Uses EventKit and requires the user's Calendar permission (full access).
- No network access, no accounts, no telemetry. Integrations (MCP, Odoo, meeting notes) come in later stages or live outside the app.
