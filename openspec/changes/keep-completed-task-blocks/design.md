## Context

See proposal.md - Why. All completion paths converge on `CalendarService.markDone`, which deletes blocks with `start > now` (and their events), sets the status and stops the timer. Every confirmed block is created through `CalendarService.insertBlock` (UI create, drag from the list, "Agendar sesión", MCP `schedule_task`) or by accepting drafts. Blocks have a draft/confirmed state but no notion of done; `BlockItem` draws a check mark on every block. Drag uses `.onDrag` with drop handling in the day column and in the task list (unschedule); resize is a bottom handle. Start prompts, the "+15 min" cascade and the MCP block tools ignore task status. The user's store is already on schema version 5.

## Goals / Non-Goals

**Goals:** keep worked blocks as an unmovable weekly record, keep future blocks of a finished ticket usable, and bring a task back when new work is scheduled for it.

**Non-Goals:** changing the calendar event (title or availability) on completion, trimming the block in progress, unlocking blocks, locking deletes, blocking edits made in Calendar.app.

## Decisions

- **Per-block `locked` flag, never cleared.** Locked means "worked history", independent of the task's current status: it survives reopening, and blocks created later are not locked. Alternative: derive from task status; rejected because reopening would unlock history and new sessions would look finished.
- **Lock started blocks in `markDone`.** It stops deleting blocks, sets `locked` on confirmed blocks with `start <= now` keeping their range, and still deletes the task's drafts (unaccepted proposals).
- **Reopen in the shared creation path.** `insertBlock` and draft acceptance set a done task's status to todo before saving, so every creation path follows the rule; `reopenedAt` is not set. Moving or resizing never changes status.
- **Schema version 6** adds `locked: Bool = false` to blocks with a custom migration stage whose `didMigrate` locks confirmed blocks with `start <= now` of tasks with status done. Version 5 is already on the user's store, so it is not edited.
- **Guards at every entry point.** `BlockItem` omits `.onDrag` and the resize handle when locked; the day column's preview and drop, and the list's unschedule drop, re-read the block from the payload and ignore locked ones (cancelled drags leave stale payloads). `CalendarService` move/update rejects locked blocks so the MCP and UI share the rule.
- **Style in one place.** One modifier applies opacity, a dashed project-color outline and the check mark for locked blocks in `BlockItem`; the month chip applies opacity and the check mark; the legend gets a third entry; the always-on check mark is removed.
- **Still busy; the cascade skips locked blocks.** Busy intervals keep locked blocks because their events still say busy. `extendBlock` excludes them from the blocks it shifts or deletes. Block notifications are removed by `remove-block-prompts`, so no prompt rule is needed.
- **External edits still sync.** Reconciliation updates a locked block's times from its event, since a change made in Calendar.app is deliberate.
- **Supersede `add-schedule-session`'s "Sessions on done tasks".** Its requirement and design note are updated to the reopen rule; its code needs no change because it creates blocks through `insertBlock`.

## Risks / Trade-offs

- [A completed task keeps future blocks while done] → intended for later stages of the same ticket; adding new blocks reopens the task.
- [Locked block in progress keeps its planned end] → chosen by the user; it can be deleted from the detail if wrong.
- [A locked block overlapped by an extended block] → accepted; the user resolves it manually.
- [Rollback] → an older build cannot open a version 6 store; roll back only by installing this release again or later.

## Migration Plan

Ship a Blockout release with schema version 6 (custom 5→6 stage that adds the field and locks started blocks of completed tasks). Rollback as above.
