## ADDED Requirements

### Requirement: Undo the last block move or resize
After the user moves a block to another time or day, or resizes it, in the calendar, ⌘Z (Edit › Deshacer) in the main window SHALL restore that block to its previous start and end and update its calendar event. Only the last move or resize SHALL be remembered: a new move or resize replaces it, and after undoing it ⌘Z SHALL NOT undo an earlier block change. There SHALL be no redo. Creating blocks (dropping a task, Option-drag copies), unscheduling, deleting, "+15 min", MCP changes and changes made outside Blockout SHALL NOT be undoable. Undo of text being edited in a text field SHALL keep working as before.

#### Scenario: Undo a move
- **WHEN** the user drags a block from Tuesday 10:00–11:00 to Thursday 15:00–16:00 and presses ⌘Z
- **THEN** the block and its calendar event return to Tuesday 10:00–11:00

#### Scenario: Undo a resize
- **WHEN** the user stretches a 10:00–11:00 block to 12:00 and presses ⌘Z
- **THEN** the block returns to 10:00–11:00

#### Scenario: Only the last change
- **WHEN** the user moves block A, then moves block B, and presses ⌘Z twice
- **THEN** only block B returns to its previous time and block A stays where it was moved

#### Scenario: Block changed meanwhile
- **WHEN** the user moves a block and then deletes it, or the block becomes locked, before pressing ⌘Z
- **THEN** ⌘Z does nothing and no error is shown

#### Scenario: Calendar write fails
- **WHEN** the user presses ⌘Z and the calendar event cannot be written
- **THEN** the block keeps its current time and the usual calendar error is shown
