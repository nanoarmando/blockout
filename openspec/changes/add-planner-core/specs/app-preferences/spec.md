## Purpose

Holds the personal settings that shape planning in Blockout: working hours and the default length of new blocks.

## ADDED Requirements

### Requirement: Working hours
Settings SHALL let the user set the start and end of the working day (8:00 to 18:00 by default). Time-based views SHALL show these hours, free time SHALL be computed inside them, and new blocks SHALL NOT be placed outside them by the drag preview.

#### Scenario: Shorter day
- **WHEN** the user sets working hours to 9:00 to 17:00
- **THEN** the views show 9:00 to 17:00 and free time is computed over 8 hours

### Requirement: Default block length
Settings SHALL let the user choose the length of new blocks: 30 minutes, 60 minutes (default) or "según la estimación" (the task estimate, or 60 minutes when there is none). The estimate is a guide and SHALL NOT set the block length under the fixed options. The same length SHALL apply to dragging a task and to scheduling through the MCP when no length is given.

#### Scenario: 30-minute default
- **WHEN** the default is 30 minutes and the user drops a task without estimate at 10:00
- **THEN** the block runs from 10:00 to 10:30

### Requirement: Settings persist
Settings SHALL be kept across app restarts and SHALL take effect without restarting the app.

#### Scenario: Restart
- **WHEN** the user changes the destination calendar and restarts Blockout
- **THEN** the new destination is still selected
