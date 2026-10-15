## Purpose

Shows the user's real calendar events and Blockout blocks together over a chosen time range, so free time and planned work are visible at a glance.

## ADDED Requirements

### Requirement: View modes
The calendar SHALL offer the views Día (today), Días (N consecutive days starting today, where N from 2 to 7 is chosen in a popup that opens from the "Días" control), Semana (Monday to Friday of the current week) and Mes (the current month grid). The control SHALL show the chosen number of days, for example "3 días". Previous, next and "Hoy" controls SHALL move the range and return to the range containing today. The title SHALL show the visible range.

#### Scenario: Choosing three days
- **WHEN** the user opens "Días" and picks 3 on Thursday 15 October
- **THEN** the calendar shows Thursday 15 to Saturday 17 October and the control reads "3 días"

#### Scenario: Month view
- **WHEN** the user selects "Mes"
- **THEN** a month grid appears where each day shows up to two blocks in their project colors and "+N" when more blocks or events exist

### Requirement: Events and blocks display
Time-based views SHALL show events from the calendars the user reads as read-only items with a dashed outline, and Blockout blocks filled with their project color and showing the block title (`[Proyecto] Título`, or the task title without a project) and time range. Short items SHALL truncate their title instead of overflowing.

#### Scenario: Read-only event
- **WHEN** the user tries to drag a calendar event that is not a Blockout block
- **THEN** the event does not move

### Requirement: Free time per day
Each day header in time-based views SHALL show the free time left inside the working hours, counting busy events and blocks once even when they overlap; events marked as free (available) SHALL NOT count. Weekend days with no working hours SHALL show "Fin de semana".

#### Scenario: Overlapping items
- **WHEN** working hours are 8:00 to 18:00 and the day has a 9:00 to 10:00 event and a 9:30 to 10:30 block
- **THEN** the header shows "Libre 8h 30m"

### Requirement: Current-time indicator
Time-based views SHALL draw a red horizontal line at the current time with a dot at its start in today's column, a fainter line across the other visible days, and the current time in red in the hour column. The line SHALL move as time passes. Days, including today, SHALL NOT be highlighted with an accent background.

#### Scenario: Viewing the week
- **WHEN** it is 11:24 on Thursday and the week view is open
- **THEN** a red line marks 11:24 in Thursday's column and a fainter line marks it on the other days

### Requirement: Light and dark appearance
The app SHALL follow the system appearance and remain legible in both: project colors in dark mode SHALL use darker fills with light text, and the current-time line SHALL stay red in both modes.

#### Scenario: Dark mode
- **WHEN** macOS switches to dark appearance
- **THEN** Blockout switches to its dark palette without a restart
