## Why

Dragging or resizing a block by mistake writes the change to the calendar at once, and the only way back is to drag it again to a time the user has to remember. A standard ⌘Z should put the block back.

## What Changes

- ⌘Z (Edit › Deshacer) restores the last block moved or resized in the calendar to its previous start and end, including its calendar event.
- Only the last change is remembered; there is no redo.
- Changes made by the MCP, by "+15 min", or outside Blockout are not undoable.

## Capabilities

### New Capabilities
- `block-move-undo`: undoing the last move or resize of a block from the calendar.

### Modified Capabilities

None.

## Impact

- App: `CalendarService.moveBlock` and its two callers in the time grid (drop and resize handle).
- No data model, MCP or settings changes.
- Docs: `README.md` and `AGENTS.md`.
