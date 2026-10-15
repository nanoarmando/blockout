## Context

New project; see proposal.md for motivation. The approved visual reference is a set of local design mockups. The author's other macOS apps (such as Minutes) are Swift packages built into an `.app` bundle by scripts and signed with a stable self-signed identity; Blockout follows the same shape so the Calendar permission survives rebuilds.

## Goals / Non-Goals

**Goals:** a native, fast planner whose blocks are real calendar events; a data model with first-class urgency, estimate and external reference so later stages and external tools need no title conventions.

**Non-Goals:** iOS or iCloud sync, multiple users, direct Google/Microsoft APIs, an MCP server (stage 2), time tracking (stage 3), public releases and the updater (stage 4).

## Decisions

### D1. Swift package + bundle script, SwiftUI, macOS 15+
`Package.swift` with one executable target, `Scripts/build.sh` assembling `Blockout.app`, signing with the "Blockout Self-Signed" identity when present (ad hoc otherwise) and optional `--install` to `/Applications`. Alternative: an Xcode project — rejected to match the author's other apps and keep the repo diff-friendly.

### D2. SwiftData for tasks, projects and blocks; UserDefaults for settings
Models: `Project` (name unique case-insensitively, color index), `PlannerTask` (title, project, urgency 0–3, estimateMinutes?, due date?, status, notes, sourceLabel?, externalRef {label, id, url}?), `Block` (task, start, end, calendar event identifier). Store in `~/Library/Application Support/Blockout`. Settings (destination calendar id, availability, read calendar ids, working hours, default length) as one `Codable` value in UserDefaults, like the author's other apps. Alternative: SQLite/GRDB — more control but extra dependency; YAGNI.

### D3. Blocks are owned by Blockout and mirrored to EventKit
Blockout is the source of truth for which blocks exist; the event is its mirror. Each event gets the URL `blockout://block/<block-uuid>` so it can be recognized even if the stored identifier changes. Writes (create, move, resize, delete) go through one `CalendarService` that saves the event first and commits the SwiftData change only on success (requirement "written immediately", no orphan blocks). Alternative: blocks stored only as events — loses task linkage when events are edited elsewhere.

### D3b. Block titles
One function builds the block title (`[Project] Title`, or the title alone) for the grid and EventKit. `CalendarService.retitleEvents(of:)` rewrites the events of all the task's blocks in one EventKit commit; it runs after title edits settle (debounced, so typing does not write per keystroke), after a project change or project rename, and after MCP `update_task`. Reconciliation never copies event titles back to tasks.

### D4. External changes via `EKEventStoreChanged`
On the notification, reconcile visible ranges: for each block, fetch its event by identifier (fallback: search by URL in the destination calendar around the block date); moved → update block times, missing → delete block. Debounced so bursts of changes run once.

### D5. Drag and drop with SwiftUI `draggable`/`dropDestination`
Tasks and blocks are `Transferable` (task id / block id). Day columns compute the time from the drop location in 15-minute steps; a shared `SlotFinder` (pure function) returns the next free slot given events, blocks and working hours, used by both the preview and the drop. Option-drag is detected from the modifier state at drop time to duplicate.

### D6. Project colors and appearance
A fixed palette of eight project colors with light (dark text on tint) and dark (tinted dark fill, light text) variants, assigned in rotation. App colors defined as asset/semantic colors following the system appearance. Fonts: system font in native chrome; the calendar keeps tabular digits.

### D6c. Time format follows macOS (approved)
Texts stay in Spanish, but times use the 12- or 24-hour clock the user set in macOS: `Locale.planner` (Spanish with the system hour cycle) for date pickers and the planner calendar, and `PlannerFormat.time`/`hourLabel` for labels ("4:00 pm" / "16:00", "9 am" / "9:00"). Spec examples are written with the 24-hour clock. MCP times stay ISO 8601.

### D6b. Icons (chosen: "B1 · línea de ahora")
App icon: graphite rounded square with three staggered time bars; the middle bar (current block) in teal `#14B8A6`, the others dark gray, crossed by the red current-time line (`#FF5A5F`) with a dot on top. Menu bar: a monochrome 16-pt template image of the same three bars and vertical line, so macOS tints it for light and dark menu bars. Source SVGs live in `Resources/` and the build script generates `AppIcon.icns`. Reference: the icon options mockup.

### D7. Quick input parsing
A pure `QuickEntryParser` returns {title, project?, estimate?, urgency} from the text and the project list: trailing `!{1,3}` → urgency; trailing `\d+(\.\d+)?h` → estimate; project = longest existing name found as a whole word/phrase (Unicode letters/digits boundaries, case-insensitive); title keeps the typed text minus the urgency and estimate tokens.

## Risks / Trade-offs

- [macOS decides when events reach Google] → document that the event is saved locally at once and synced by macOS, usually within seconds; destination must be an account calendar, not "On My Mac".
- [Event identifiers can change after account resyncs] → URL marker fallback (D3).
- [Large calendars slow down month view] → fetch only the visible range plus a small margin.
- [SwiftData migrations in later stages] → keep the schema versioned from day one (`VersionedSchema`).

## Migration Plan

None: new app. Anchor keeps working in parallel until stage 2 migrates the author's automation.
