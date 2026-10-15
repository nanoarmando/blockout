# AGENTS.md

## Structure

- `Package.swift`: one executable target `Blockout` (Swift 6, macOS 15, no dependencies).
- `Sources/Blockout/App/BlockoutApp.swift`: app entry, model container, settings and calendar service wiring.
- `Sources/Blockout/Models/`:
  - `Schema.swift`: versioned SwiftData schema with `Project`, `PlannerTask`, `Block`, `TimeEntry`: `BlockoutSchemaV1`, `BlockoutSchemaV2` (adds `Block.stateRaw` draft|confirmed and `proposalID`), `BlockoutSchemaV3` (adds `TimeEntry` task/start/end?, deleted with its task) and the lightweight migration plan. `BlockoutStore.makeContainer` honors `BLOCKOUT_STORE_DIR`. The typealiases point at the latest version. Add new versions here; never edit a shipped version in place.
  - `PlannerTask+State.swift`: derived task state (scheduled, next block, overdue, scheduled minutes).
  - `AppSettings.swift`: the single `Codable` settings value stored in UserDefaults and its `SettingsStore`.
  - `Theme.swift`: project palette (8 colors, light and dark variants, assigned in rotation) and app colors.
  - `CalendarRange.swift`: view modes (Día, Días, Semana, Mes) and visible ranges.
- `Sources/Blockout/Services/`:
  - `CalendarService.swift`: the only EventKit access point: permission, calendars by account, events for a range, block writes and reconciliation on `EKEventStoreChanged`.
  - `QuickEntryParser.swift`: pure parser for the filter-and-create input (title, project, estimate, urgency).
  - `SlotFinder.swift`: pure function for the next free slot in 15-minute steps inside working hours.
  - `PlannerFormat.swift`: shared Spanish date, time and duration formatting.
  - `DragState.swift`: shared drag payload for the live drop preview.
  - `MCPServer.swift`: `NWListener` on 127.0.0.1 (default port 43219), one HTTP/1.1 `POST /mcp` request per connection, JSON-RPC `initialize`, `ping`, `tools/list`, `tools/call`; notifications get 202; non-local `Origin` headers are rejected.
  - `TimeTracker.swift`: the single timer and every `TimeEntry` write (start, pause, stop, resume, complete, "+15 min", manual entries); heartbeat every minute (UserDefaults `timerHeartbeat`), open entries closed at the last heartbeat on launch and at quit time on normal quit.
  - `BlockCascade.swift`: pure cascade of later blocks after an extension (moved, removed); applied by `CalendarService.extendBlock` in one EventKit commit.
  - `StartPrompts.swift`: start notifications for today's confirmed blocks ("Sí, empezar", "En 5 min", "Saltar"), rescheduled whenever `CalendarService.revision` changes; snooze/skip state is in memory.
  - `MCPTools.swift`: tool handlers on the main actor. `MCPToolDefinitions.swift`: names, descriptions and JSON input schemas for `tools/list`.
- `Sources/Blockout/Views/`: SwiftUI views (`ProjectSheet` creates/edits projects from the sidebar "+" and project context menu, rejecting duplicate names case-insensitively; main split, sidebar, task list, time grid, month grid, task detail with "Tiempo registrado", settings, `MenuBarView` for the `MenuBarExtra(.menu)` item and menu, shared components).
- `App/BlockoutApp.swift` also holds the `AppDelegate`: closing the window keeps the app running (menu bar and Dock); the Dock icon reopens it.
- `Sources/Blockout/Updates/` (ported from Minutes): `UpdateRelease.swift` (versions, release decoding), `UpdateClient.swift` (unauthenticated GitHub Releases API; 404 = no published releases, an error shown only in About), `UpdateInstaller.swift` (DMG download to `~/Library/Caches/Blockout/updates`, read-only mount, designated-requirement and version checks before and after copying, detached swap script with rollback; refuses ad hoc builds), `UpdateCoordinator.swift` (check at launch, every 24 h and when About appears; install disabled while `TimeTracker.running != nil`). `Views/AboutView.swift`: About window (app menu, menu bar menu, Settings).
- `Resources/`: `Info.plist` (calendar usage description), `AppIcon.svg` (B1 icon), `MenuBarIcon.svg` (16-pt template, used in stage 3).
- `Scripts/build.sh`: universal release build, assembles `dist/Blockout.app`, renders `AppIcon.icns` from the SVG, signs with `Blockout Self-Signed` (or `$BLOCKOUT_SIGN_IDENTITY`, ad hoc fallback), `--install` copies to `/Applications`.
- `docs/design/` (local only, excluded through `.git/info/exclude` because it contains real calendar and client data; never commit it): approved mockups as `.dc.html` sources (exact colors, sizes, copy and interactions in `renderVals()`): `Main` (planner, light), `MainOscuro` (dark), `Tarea` (task detail), `Ajustes` (settings and calendar picker), `MenuBar` (menu bar and start notification, stage 3), `Iconos` (chosen: "B1 · línea de ahora"). Design references only: rebuild natively in SwiftUI.
- `openspec/changes/<id>/`: one change per stage (`add-planner-core`, `add-mcp-server`, `add-time-tracking`, `add-public-release`), each with `proposal.md`, `design.md`, `tasks.md` and `specs/<capability>/spec.md`.
- `Scripts/build-dmg.sh <version>`: checks `<version>` against `VERSION`, runs `build.sh --release` (fails instead of signing ad hoc when the identity is missing) and writes `dist/Blockout-<version>.dmg` with an Applications link.
- `VERSION`: app version read by the build script. `LICENSE`: GPL-3.0.

## Contracts

- Blockout is the source of truth for blocks; each EventKit event is a mirror. Every block write goes through `CalendarService`: save the event first, commit SwiftData only on success, so there are no orphan blocks.
- Block events carry the URL `blockout://block/<block-uuid>` (lowercase) as a fallback identifier, the block title `PlannerTask.blockTitle` (`[Project] Title`, or the title alone; the task title never stores the prefix) and the availability from settings (busy by default). Title, project or project-name changes retitle the events of all the task's blocks through `CalendarService.retitleEvents(of:)` (task detail: after a 1 s pause and on close; project sheet on rename; MCP `update_task`, which returns `warning` if the events could not be updated). Event titles are never copied back to tasks.
- Reconciliation updates block times from their events and deletes blocks whose event is gone, but never deletes while the destination calendar is unavailable (account resyncing).
- Events of blocks are hidden from the event list so a block is never drawn twice.
- Deleting a task (list context menu "Eliminar…" with confirmation, or MCP `delete_task`) always goes through `CalendarService.removeTask`: every block (past, future, drafts) and its event, then the task; time entries cascade.
- New-block placement (preview and drop) always uses `SlotFinder`; moving or resizing an existing block may overlap other items.
- Drafts (`BlockState.draft`) never have a calendar event, never count as scheduled time or against free time, and are ignored by reconciliation. Use `confirmedBlocks` / `CalendarService.blocks(in:)` for anything that counts as scheduled. Acceptance re-validates each draft and leaves conflicting ones as drafts.
- MCP tools reuse the UI services (`CalendarService` throwing block writes, `SlotFinder`, `ModelContext.project(named:)`); never duplicate a business rule in `MCPTools`. Tool contract: arguments `task_id`, `block_id`, `start` (ISO 8601), `length_minutes`; statuses `todo`, `in_progress`, `waiting`, `done`; `color` is the palette index 0–7; results are JSON text content; failures return `isError: true` and change nothing; `delete_*` need `confirm: true`. External automations depend on this contract: keep it backward compatible.
- Time tracking: one running entry at a time; pause and stop both close the entry (they differ only in the menu state). Completing a task from any path stops its timer through `CalendarService.onTaskDone`. "+15 min" is offered only while the timer runs for the block in progress; the cascade never moves events or drafts and removes blocks that end after working hours. `list_time_entries` (`from`, inclusive `to`) returns entries by start, with `running` and `end: null` for the open one.
- Release contract: tag `v<x.y.z>` with the asset `Blockout-<x.y.z>.dmg` containing `Blockout.app` signed with "Blockout Self-Signed" and `CFBundleShortVersionString` equal to the tag; the updater rejects anything else. Never add tokens to the update check.
- Store: `~/Library/Application Support/Blockout/Blockout.store`.

## Rules

- Do not implement any change before the user approves its spec summary (OpenSpec workflow). Implement stages in order. All four stages are implemented; manual verification (1: 8.1, 2: 5.2, 3: 6.1, 4: 4.1) are pending; 1.0.0 is published at github.com/nanoarmando/blockout. Never push or publish a release without the user's explicit confirmation, and never commit client data, real calendar data or references to the author's private tools (the repository is public).
- Do not add automated tests unless a requirement asks for them.
- Do not add third-party dependencies or network access (only the local MCP and the GitHub release check).
- When testing from a debug build, set `BLOCKOUT_STORE_DIR` to a scratch folder so the real store is untouched (redirecting `HOME` does not work: `URL.applicationSupportDirectory` ignores it), and avoid `schedule_task`, draft acceptance and "+15 min": they write real calendar events.
- Integrations with Odoo or meeting notes never go into Blockout; they live in external tools that use the MCP.
- UI copy in neutral Spanish (no regional forms such as "filtrá" or "arrastrá"); code, comments and docs in English. Times follow the macOS 12/24-hour setting: use `Locale.planner` for pickers and `PlannerFormat.time`/`hourLabel` for labels, never a hard-coded "es" locale or "%d:00".
- Localization is planned (README Roadmap) but not set up: there is no String Catalog and texts are literals. Until it is planned as its own OpenSpec change, prefer SwiftUI literals (`Text("…")`, `Button("…")`), which become localization keys automatically, over building user-facing text as `String`.
- Keep README.md (humans) and AGENTS.md (agents) in sync.
