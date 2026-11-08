## 1. View modes

- [x] 1.1 Remove the Días mode, `dayCount`, its segment and popover, and show seven days in the week view (Three view modes)

## 2. Weekend drops

- [x] 2.1 Add `AppSettings.workingHours(on:)`, keep `workday(containing:)` for weekdays only, and use the new helper in the task drop preview (Tasks can be dropped on weekends)

## 3. Navigation

- [x] 3.1 Add the trackpad swipe monitor on the calendar area, one step per gesture (Trackpad swipe navigation)
- [x] 3.2 Add the edge zone and repeating 0.8 s dwell to `DragState`, report it from the first and last day columns, and step the range from `MainView` in Día and Semana (Edge navigation while dragging)

## 4. Related change and docs

- [x] 4.1 Add a note to `add-planner-core`'s "View modes" requirement pointing to this change
- [x] 4.2 Update `README.md` and `AGENTS.md` (view modes, seven-day week, weekend drops, swipe and edge navigation)
- [ ] 4.3 Verify every scenario with a debug build on a scratch store and a test calendar
