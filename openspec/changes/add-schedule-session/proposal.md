## Why

The task detail offers "+ Agendar las horas restantes", which only appears while the estimate exceeds the scheduled time and books all the remaining hours as one block. In practice estimates drift, tasks get reopened or keep needing time after being closed, and the user wants to add one more working session, not the whole remainder. The action is hidden exactly when it is needed (no estimate, estimate already scheduled, task done).

## What Changes

- Replace "+ Agendar las horas restantes" with "+ Agendar sesión" in the task detail.
- "Agendar sesión" always appears and books one block with the default block length from settings, in the first free slot today within working hours from the next quarter hour; if today has no free slot, in the first free slot of the following working days, as the old action searched.
- It works the same for open and done tasks and never changes the task's status.
- **BREAKING (UI):** the remaining-hours action is removed; the "Xh de Yh agendada" summary stays.

## Capabilities

### New Capabilities
- `schedule-session`: the "Agendar sesión" action in the task detail, its slot search, its length and its behavior on done tasks.

### Modified Capabilities

None (`add-planner-core` is not archived yet; this change supersedes the "+ Agendar las horas restantes" part of its "Task detail" requirement).

## Impact

- App: task detail blocks section.
- Docs: `README.md` and `AGENTS.md` mentions of "Agendar las horas restantes".
- Depends on `add-planner-core`.
