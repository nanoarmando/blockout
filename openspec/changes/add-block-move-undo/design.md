## Context

See proposal.md - Why. Every move and resize from the calendar goes through `CalendarService.moveBlock(_:start:end:)`, which wraps the throwing `updateBlock` (event first, then the store) and reports failures through the UI alerts. Its callers are the day column's `performDrop` (block payload without Option) and the resize handle in `BlockItem`. The MCP uses `updateBlock` directly. The app has the standard SwiftUI Edit menu; there is no undo registration today.

## Goals / Non-Goals

**Goals:** a single-step ⌘Z for block moves and resizes made in the calendar.

**Non-Goals:** redo, multi-step history, undoing creation, deletion, unscheduling, "+15 min", MCP or external changes, a custom menu item.

## Decisions

- **Window undo manager.** The two callers read `@Environment(\.undoManager)` and pass it to `moveBlock(_:start:end:undoManager:)` (optional, default `nil`, so other callers are unchanged). The standard Edit › Deshacer item and ⌘Z then work through the responder chain, and text fields keep their own undo when they are editing.
- **One step, block actions only.** On success, `moveBlock` calls `removeAllActions(withTarget: self)` and registers one action with `CalendarService` as target that restores the previous start and end with action name "Mover bloque". Clearing by target keeps text-editing undo actions in the same manager. The restore calls `updateBlock` through `perform` without registering anything, so there is no redo and no earlier step.
- **Skip stale blocks.** The restore does nothing when the block was deleted (`block.modelContext == nil` or `isDeleted`) or is locked, so no error appears for a change that no longer applies. Other failures (no access, missing event) use the usual alert and leave the block unchanged.

## Risks / Trade-offs

- [The menu shows the system wording around "Mover bloque"] → acceptable until localization is planned.
- [A move from another window (for example a sheet) is not undone from the main window] → moves only happen in the main window's calendar.

## Migration Plan

None. Rollback is installing the previous release.
