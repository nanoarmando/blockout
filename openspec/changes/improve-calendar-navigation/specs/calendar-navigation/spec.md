## ADDED Requirements

### Requirement: Three view modes
The calendar SHALL offer the views Día (one day), Semana (Monday to Sunday of the week) and Mes (the month grid). The "Días" view and its day-count popup SHALL NOT exist. Previous, next and "Hoy" controls SHALL move one day, one week or one month depending on the view and return to the range containing today. The title SHALL show the visible range. The app SHALL start in the Semana view of the current week.

#### Scenario: Week shows the weekend
- **WHEN** the user opens the Semana view on Thursday 12 November 2026
- **THEN** the calendar shows Monday 9 to Sunday 15 November as seven columns

#### Scenario: Next week
- **WHEN** the user presses the next control in the Semana view
- **THEN** the calendar shows Monday 16 to Sunday 22 November, including Saturday and Sunday

#### Scenario: Next day reaches Saturday
- **WHEN** the user presses the next control in the Día view on Friday 13 November
- **THEN** the calendar shows Saturday 14 November

#### Scenario: No Días control
- **WHEN** the user looks at the view selector
- **THEN** it shows only Día, Semana and Mes

### Requirement: Tasks can be dropped on weekends
Dropping a task on Saturday or Sunday SHALL follow the same rules as on a weekday: the block lands under the pointer in 15-minute steps inside the visible hours (the working hours from settings), and overlapping busy time is a conflict that refuses the drop. Weekend day headers SHALL keep showing "Fin de semana". Automatic scheduling ("+ Agendar sesión" and MCP `schedule_task`) SHALL keep skipping weekends.

#### Scenario: Drop on Saturday
- **WHEN** the user drops a task at 10:00 on Saturday with no other item at that time and the default length is 60 minutes
- **THEN** a 10:00 to 11:00 Saturday block is created and written to the calendar

#### Scenario: Conflict on Sunday
- **WHEN** the user drags a 1-hour task to 13:45 on Sunday and a busy event runs from 14:00 to 14:30
- **THEN** the preview shows "No se puede planificar aquí porque coincide con otra actividad" and dropping does nothing

#### Scenario: Agendar sesión on Friday evening
- **WHEN** the user chooses "+ Agendar sesión" on Friday after the working hours
- **THEN** the block is placed on Monday, not on the weekend

### Requirement: Trackpad swipe navigation
A horizontal two-finger swipe over the calendar area SHALL move exactly one period, the same as one press of the previous or next control in the current view (Día, Semana or Mes). Swiping toward the left (content moving left) SHALL go forward and swiping toward the right SHALL go back, following the system scroll direction setting. One gesture SHALL move at most one period, including its momentum. Gestures that are mainly vertical SHALL keep scrolling the grid and SHALL NOT change the period. Swipes over the task list, the sidebar or other windows SHALL NOT change the period.

#### Scenario: Swipe to next week
- **WHEN** the Semana view shows 9 to 15 November and the user swipes horizontally to go forward
- **THEN** the calendar shows 16 to 22 November and does not jump further while the momentum ends

#### Scenario: Vertical scroll
- **WHEN** the user scrolls mostly vertically over the time grid
- **THEN** the grid scrolls and the period does not change

#### Scenario: Swipe over the list
- **WHEN** the user swipes horizontally over the task list
- **THEN** the calendar period does not change

### Requirement: Edge navigation while dragging
While the user drags a task or an unlocked block over the Día or Semana grid, keeping the pointer within the edge zone of the first or last day column (the outer 30 points) for 0.8 s SHALL move the calendar one period back or forward, and SHALL repeat every 0.8 s while the pointer stays in that zone. Leaving the zone, dropping or cancelling the drag SHALL stop it. After the period changes, the drag SHALL continue and can be dropped on the new range with the usual rules. The Mes view SHALL NOT navigate while dragging.

#### Scenario: Move a block to next week
- **WHEN** the user drags a Thursday block to the right edge of the Sunday column and holds it there for 0.8 s
- **THEN** the calendar shows the next week, and dropping the block on Tuesday moves it there

#### Scenario: Passing by the edge
- **WHEN** the pointer crosses the edge zone in less than 0.8 s
- **THEN** the period does not change

#### Scenario: Holding at the edge
- **WHEN** the user keeps the pointer in the left edge zone for 2 seconds in the Día view
- **THEN** the calendar moves back two days

#### Scenario: Cancelled drag
- **WHEN** the user drags to the edge zone and cancels the drag with Esc before 0.8 s
- **THEN** the period does not change and nothing is created or moved
