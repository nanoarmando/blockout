## 1. Project setup

- [x] 1.1 Create `Package.swift` (macOS 15, Swift 6, executable target `Blockout`), `Resources/Info.plist` with `NSCalendarsFullAccessUsageDescription`, `VERSION`, `.gitignore` (D1)
- [x] 1.2 Write `Scripts/build.sh` that builds a universal release, assembles `Blockout.app`, signs with "Blockout Self-Signed" when present (ad hoc otherwise) and supports `--install` (D1)
- [x] 1.3 Add the B1 app icon and menu bar template SVGs and generate `AppIcon.icns` in the build script (D6b)
- [x] 1.4 Write `README.md` (what it is, build, signing identity setup, permissions) and `AGENTS.md` (structure, conventions, contracts)

## 2. Data model and settings

- [x] 2.1 Define versioned SwiftData models `Project`, `PlannerTask`, `Block` and the store location (D2)
- [x] 2.2 Define the `Settings` value (destination, availability, read calendars, working hours, default length) persisted in UserDefaults (D2; app-preferences)
- [x] 2.3 Implement the project color palette with light and dark variants and rotation (D6)

## 3. Calendar service

- [x] 3.1 Implement `CalendarService`: permission request and state, list calendars by account, fetch events for a range from the read calendars (calendar-sources)
- [x] 3.2 Implement block event writes (create, update, delete) with the `blockout://block/<uuid>` URL and availability, committing model changes only after a successful save (D3; block-scheduling)
- [x] 3.3 Reconcile blocks on `EKEventStoreChanged` with debouncing and the URL fallback (D4)

## 4. Task list

- [x] 4.1 Implement `QuickEntryParser` (D7)
- [x] 4.2 Build the filter-and-create input with live filtering, match count, detected-project hint and Enter to create (task-management)
- [x] 4.3 Build the "Sin agendar" / "Agendadas" groups and task rows with project badge, urgency indicator, estimate, source, next block and due date
- [x] 4.4 Build the sidebar: filters with counts, top five projects with "Ver más"/"Ver menos", source filters

## 5. Calendar views

- [x] 5.1 Build the time grid for Día, Días (popup 2–7) and Semana with navigation, title range and hour column (calendar-view)
- [x] 5.2 Render events (dashed, read-only) and blocks (project colors), hiding duplicates of block events
- [x] 5.3 Compute and show free time per day within working hours; "Fin de semana" for days without hours
- [x] 5.4 Draw the current-time line and red time label, updating every minute
- [x] 5.5 Build the month grid with up to two blocks per day and "+N"

## 6. Scheduling interactions

- [x] 6.1 Implement `SlotFinder` (15-minute steps, next free slot, working hours) (D5)
- [x] 6.2 Drag a task onto a day with live preview and drop to create a block (block-scheduling)
- [x] 6.3 Move and resize blocks; Option-drag to duplicate; drag back to the list to unschedule
- [x] 6.4 Delete not-started blocks when a task is completed

## 7. Task detail and settings

- [x] 7.1 Build the task detail (status, urgency, estimate, due date, origin, external link, blocks list with remove, "agendar las horas restantes", notes) with autosave
- [x] 7.2 Build Settings: destination calendar and availability, read-calendars summary and picker (search, groups, Todos/Ninguno, count, Listo), working hours, default length
- [x] 7.3 Show the permission-denied state with the button to System Settings
- [x] 7.4 Add the task row context menu (Abrir, Urgencia submenu, Eliminar…) and task deletion with confirmation, sharing one deletion path with the MCP `delete_task` (task-management)
- [x] 7.5 Replace the sidebar "Nuevo proyecto" field with a "+" button and add a project sheet (name, palette color) for creating and, from the project context menu, editing projects (task-management)
- [x] 7.6 Title blocks and their events "[Proyecto] Título" and retitle all of a task's events when its title, project or project name changes, from the UI and the MCP (D3b; block-scheduling, calendar-view)

## 8. Verification

- [ ] 8.1 Manually verify every scenario of the five specs against a real Google account in macOS Calendar, including busy status seen from another account
