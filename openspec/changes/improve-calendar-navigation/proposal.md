## Why

Moving through the calendar is slower than it should be. The week view shows only Monday to Friday, so weekends can never be seen or planned from it; the "Días" view adds little over "Día" and "Semana"; the trackpad does nothing horizontally; and a block or task can only be dropped inside the range already on screen, so moving work to next week means dropping it, navigating and dragging again.

## What Changes

- **BREAKING (UI):** the "Días" view and its day-count popup are removed. The views are Día, Semana and Mes.
- The week view shows the seven days, Monday to Sunday; the previous and next controls therefore reach weekends.
- Tasks can be dropped on Saturday and Sunday inside the same visible hours as weekdays. Automatic scheduling ("+ Agendar sesión", MCP `schedule_task`) keeps skipping weekends.
- A horizontal two-finger trackpad swipe over the calendar moves one period back or forward, exactly like the previous and next controls (one day, week or month depending on the view). Vertical scrolling is unchanged.
- While dragging a task or a block in the Día or Semana view, holding the pointer near the left or right edge of the grid for 0.8 s moves to the previous or next period; it repeats every 0.8 s while the pointer stays there.

## Capabilities

### New Capabilities
- `calendar-navigation`: view modes, the seven-day week, swipe navigation, weekend drops and edge navigation while dragging.

### Modified Capabilities

None (`add-planner-core` is not archived yet; this change supersedes its "View modes" requirement and the weekend part of "Create a block by dragging a task").

## Impact

- App: `CalendarRange`, the calendar header, the time grid drop targets, the calendar area (swipe and edge handling), `AppSettings` working hours.
- No data model, MCP or settings changes.
- Docs: `README.md` and `AGENTS.md`; `add-planner-core`'s "View modes" requirement is updated to point to this change.
