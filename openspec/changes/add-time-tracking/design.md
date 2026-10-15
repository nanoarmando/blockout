## Context

See proposal.md. Blocks, `CalendarService`, `SlotFinder` and the MCP server exist from earlier stages. The approved menu design mimics a native macOS menu; Minutes already uses a similar "Are you in a meeting?" prompt pattern.

## Goals / Non-Goals

**Goals:** reliable entries with minimal clicks; a cascade that never touches meetings.

**Non-Goals:** writing timesheets to Odoo (its MCP is read-only), idle detection, a report view, Pomodoro.

## Decisions

### D1. `MenuBarExtra` with `.menu` style
Native menu rendering for free (material, font, separators, ⌘ shortcuts). Alternative: `.window` style popover — custom look, rejected because the user asked for the native menu.

### D2. `UNUserNotificationCenter` with a category and three actions
Scheduled for each block start of today (rescheduled on block changes). Actions handled in the app delegate. Snooze schedules a one-shot five minutes later if the block is still in progress.

### D3. Time entries persisted incrementally
`TimeEntry` (task, start, end?) saved when started; a running entry has no end. On launch, an open entry is closed at the last heartbeat (written every minute) so a crash loses at most one minute; on normal quit it is closed at quit time.

### D4. Cascade as a pure function
`cascade(blocks, events, from:, workingHours:) -> (moved, removed)` reused by the menu summary and the writer; applied through `CalendarService` in one batch so the menu reflects a consistent state.

### D5. Clarifications (approved)
- Closing the main window keeps Blockout running (menu bar item and Dock icon), since the timer and the MCP server need it; ⌘Q or "Salir" quits.
- "Completar" during a block keeps the block in progress with its original range; only blocks that have not started are deleted, as in the planner's completion rule.
- "Pausar" and "Detener" both close the running entry; they differ only in the menu state ("Reanudar" vs "Detenido" with "Retomar").

## Risks / Trade-offs

- [Notifications denied] → the prompt lives in the menu ("Empieza ahora · Empezar").
- [Cascade surprises] → it only runs on explicit "+15 min", and the menu shows every move as "antes → ahora".
- [Many events in a day] → cascade is O(n) per extension; trivial sizes.

## Migration Plan

SwiftData schema v3 adds `TimeEntry`; no data transformation.
