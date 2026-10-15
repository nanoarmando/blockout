## 1. Model

- [x] 1.1 Add `TimeEntry` (schema v3) and the timer service with one running entry, heartbeat and close-on-launch (D3; time-tracking)

## 2. Prompt and timer

- [x] 2.1 Request notification permission and register the category with "Sí, empezar", "En 5 min", "Saltar" (D2)
- [x] 2.2 Schedule prompts for today's block starts, rescheduling on block changes; handle the three actions
- [x] 2.3 Implement start, pause/resume, stop/resume and complete, enforcing one timer at a time

## 3. Menu bar

- [x] 3.1 Build the `MenuBarExtra` item with elapsed time and short task name (D1; menu-bar)
- [x] 3.2 Build the native menu: current/next block, applicable actions, "Después" with shift marks, Abrir Blockout and Ajustes…

## 4. Extension and cascade

- [x] 4.1 Implement the pure cascade function (D4; block-extension)
- [x] 4.2 Wire "+15 min": extend, cascade, write events in one batch, unschedule overflow, summary in the menu

## 5. Task detail and MCP

- [x] 5.1 Add the time section to the task detail: editable entries with validation, delete, manual entry, total vs estimate, "Retomar cronómetro"/"Detener"
- [x] 5.2 Add `list_time_entries` to the MCP server
- [x] 5.3 Update README and AGENTS

## 6. Verification

- [ ] 6.1 Verify every scenario of the three specs, including notifications denied and quitting with a running timer
