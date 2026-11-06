## Context

See proposal.md - Why. The current action lives in the task detail: it computes the remaining minutes, then searches today and the next 13 days for the first free slot inside working hours from the next quarter hour, and creates one block through the calendar service. Block creation never touches the task's status. The default block length setting already resolves a length per task and is used by drag-and-drop and the MCP `schedule_task`.

## Goals / Non-Goals

**Goals:** one always-visible action that books one default-length session, reusing the existing slot search.

**Non-Goals:** splitting sessions, choosing a day or time in the action, changing the default block length setting.

## Decisions

- **Reuse the existing search, change only the length.** The day loop, next-quarter-hour start, working-hours limit, two-week horizon and error message stay as they are; the length comes from the settings' per-task block length instead of the remaining estimate. Alternative: always today ignoring working hours; rejected by the user in favor of the next working day.
- **Length from the setting as configured.** "60 min" and "30 min" use that length; "Según la estimación" keeps its current meaning (the task's estimate, or 60 minutes without one), the same as drag-and-drop and the MCP.
- **Reopen on done tasks.** Creating a block on a done task reopens it to todo without the reopened mark, through the shared block creation path (`keep-completed-task-blocks`); the action itself has no status logic.
- **Remove the remaining-minutes value from the detail** once the action no longer uses it (YAGNI); the summary keeps using scheduled minutes and the estimate.

## Risks / Trade-offs

- ["Según la estimación" with a large estimate books a long block, or finds no slot] → same as dropping the task on the calendar today; the user picks a fixed length in settings if that is a problem.
- [Scheduling a session on a done task reopens it] → intended: new work means the task is open again; its earlier worked blocks stay locked.

## Migration Plan

No data changes. Ships in the next Blockout release; rollback by installing the previous release.
