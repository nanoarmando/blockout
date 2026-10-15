## Purpose

Connects Blockout to the calendars the user already has in macOS: which ones are read, which one receives the blocks, and how changes made outside Blockout are reflected.

## ADDED Requirements

### Requirement: Calendar permission
Blockout SHALL request full access to calendars on first use. Without it, the calendar area SHALL explain that access is needed and offer a button that opens the matching pane of System Settings; task management SHALL keep working.

#### Scenario: Permission denied
- **WHEN** the user denies calendar access
- **THEN** the calendar shows the explanation and the button, and tasks can still be created and edited

### Requirement: Calendars that are read
Settings SHALL show the calendars that are read as a summary ("2 de 10 · Trabajo, Globex") and an "Elegir…" button that opens a picker. The picker SHALL list every calendar available in macOS grouped by account with its color and a checkbox, offer a search field, a "Todos"/"Ninguno" toggle per account, a count of selected calendars and a "Listo" button. Only selected calendars SHALL appear in the views and count toward free time.

#### Scenario: Searching among many calendars
- **WHEN** the user types "globex" in the picker
- **THEN** only calendars whose name contains "globex" are listed, still grouped by account

#### Scenario: Select a whole account
- **WHEN** the user activates "Todos" for the iCloud account
- **THEN** every iCloud calendar becomes selected and the toggle reads "Ninguno"

### Requirement: Destination calendar
Settings SHALL let the user choose one writable calendar as the destination for blocks and the availability of block events (busy by default, or free). The blocks' own events SHALL NOT be shown twice when the destination is also a calendar that is read.

#### Scenario: Destination also read
- **WHEN** "Trabajo" is both read and the destination
- **THEN** each block appears once, as a block, not also as a dashed event

### Requirement: Changes made outside Blockout
When a block's event is moved, resized or deleted in Calendar or another client, Blockout SHALL update or remove the block accordingly as soon as macOS reports the change. Changes to other events SHALL be reflected in the views and free time.

#### Scenario: Event deleted in Calendar
- **WHEN** the user deletes a block's event in the Calendar app
- **THEN** the block disappears from Blockout and, if it was the task's only upcoming block, the task returns to "Sin agendar"

#### Scenario: Event moved in Google Calendar on the web
- **WHEN** the event is moved on the web and macOS syncs the change
- **THEN** the block shows the new time
