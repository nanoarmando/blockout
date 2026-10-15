## Purpose

Lets the user extend the block in progress without manually re-planning the rest of the day, while never touching meetings.

## ADDED Requirements

### Requirement: Extend the current block
"+15 min" SHALL extend the end of the block in progress by 15 minutes and update its calendar event immediately. It SHALL be available only while that block's timer runs.

#### Scenario: Extend once
- **WHEN** the 11:00–12:00 block is extended once
- **THEN** it ends at 12:15 and its event ends at 12:15

### Requirement: Cascade of later blocks
After an extension, each later block of the same day that would overlap SHALL move to start when the previous one ends, keeping its length. A block that would overlap a calendar event SHALL move to start when that event ends. Calendar events SHALL never move. Blocks that would end after the working hours SHALL be removed with their events and their tasks SHALL return to "Sin agendar". The menu SHALL summarize the shift ("Extendida 15 min · se corrieron N bloques") and list blocks that no longer fit.

#### Scenario: Cascade around a meeting
- **WHEN** the 11:00–12:00 block is extended 15 minutes, blocks follow at 12:00–13:00 and 13:00–14:00, a meeting runs 14:00–14:30 and another block is at 15:00–16:00
- **THEN** the blocks move to 12:15–13:15, 14:30–15:30 and 15:30–16:30, and the meeting stays at 14:00

#### Scenario: Overflow
- **WHEN** working hours end at 18:00 and the cascade pushes a 1-hour block to start at 17:30
- **THEN** that block and its event are removed, its task returns to "Sin agendar" and the menu lists it as "Sin lugar"
