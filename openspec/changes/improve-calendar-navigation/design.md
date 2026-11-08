## Context

See proposal.md - Why. `CalendarRange` (`Models/CalendarRange.swift`) holds the mode (`day`, `days`, `week`, `month`), the anchor and `dayCount`; `.week` builds 5 days from Monday (`Calendar.planner.firstWeekday = 2`) and `step` adds ±1 day, ±dayCount, ±1 week or ±1 month. The range is `@State` in `MainView` and is not persisted. `CalendarHeader` draws the arrows, "Hoy", the mode segments and the Días popover. The time grid is a vertical `ScrollView` with one `DayColumn` per day; each column has its own `DropDelegate` whose `info.location` is local to the column. `AppSettings.workday(containing:)` returns `nil` on weekends and is used by the free-time label, the task drop preview and `SlotFinder`. There is no scroll-wheel handling and the month grid has no drop targets.

## Goals / Non-Goals

**Goals:** see and plan weekends from the week view, navigate with the trackpad, and move work to another period in one drag.

**Non-Goals:** a year view, persisting the selected view, configurable working days, navigation keyboard shortcuts, dropping on the month grid, changing `SlotFinder` or the MCP.

## Decisions

- **Remove `.days`.** Drop the case, `dayCount`, the Días segment, `showsDayCount` and `dayCountPicker`. Nothing persists the mode, so no migration is needed.
- **Seven-day week.** `.week` builds 7 days from `startOfWeek`. Columns are flexible, so the grid fits the existing minimum window width.
- **Weekend drops through a separate helper.** Add `AppSettings.workingHours(on:)` (the working interval of any day); `workday(containing:)` keeps returning `nil` on weekends and calls it otherwise. The task drop preview uses `workingHours(on:)`, so weekends accept drops inside the visible hours; `SlotFinder`, the free-time label and the MCP keep using `workday(containing:)`. Alternative: drop the weekend rule entirely; rejected because automatic scheduling must keep skipping weekends.
- **Swipe through a local scroll-wheel monitor.** A small `NSViewRepresentable` placed as the calendar area background installs `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)` while the view is in a window and removes it on dismantle. It only acts when the event's window is the view's window and the location is inside the view's bounds, `hasPreciseScrollingDeltas` is true (trackpad, not mouse wheel), and the horizontal delta dominates. It accumulates `scrollingDeltaX` from `phase == .began` and calls `step(±1)` once when the accumulated value passes a threshold (about 40 points), then ignores the rest of the gesture and its momentum phase until the next `.began`. `scrollingDeltaX` already follows the user's natural-scrolling setting, so forward is negative delta (content moves left). Events are always passed through, so vertical scrolling is unaffected. Alternative: `onScrollGesture` style SwiftUI APIs; macOS 15 has none for horizontal wheel deltas on a non-scrolling view.
- **Edge dwell in `DragState`.** `DayColumn` already receives `dropUpdated` with a local location and knows its width (`GeometryReader`). The first column reports the left zone when `x < 30`, the last column the right zone when `x > width - 30`; any other location or `dropExited`/`performDrop`/`finish` clears it. `DragState` gains `edge: Edge?` with a single repeating 0.8 s `Task`: setting a new edge restarts it, clearing cancels it, and each tick calls an injected `onEdgeStep(±1)` closure that `MainView` sets to `range.step`. The pointer may stay still while SwiftUI stops calling `dropUpdated`, which is why the timer repeats on its own instead of depending on further callbacks. Only enabled for Día and Semana (the time grid is the only view with drop targets). Locked block payloads already produce no preview and do not arm the edge.
- **Drag survives the range change.** The payload lives in `DragState`, and the rebuilt columns reload it in `dropEntered`, so the drop on the new range uses the normal rules. After a step, the edge is cleared and re-armed by the next `dropUpdated` in the new edge column.
- **Supersede `add-planner-core`'s "View modes".** Its requirement text gets a note pointing to this change; its behavior for Día and Mes stays.

## Risks / Trade-offs

- [A long, fast swipe moves only one period] → intended, matching the arrow controls; repeat the swipe for more.
- [SwiftUI may not send `dropEntered` to a column rebuilt under a still pointer] → the payload is kept in `DragState`, and moving the pointer slightly triggers the callbacks; verify manually.
- [Events refetch after a step] → the conflict check may briefly see no events until the fetch ends; the drop re-validates on release with the loaded events.
- [Weekend free-time label stays "Fin de semana" although drops are allowed] → keeps the header simple and matches the automatic scheduling rule.

## Migration Plan

No data or settings migration. Rollback is installing the previous release.
