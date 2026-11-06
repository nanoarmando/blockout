# Blockout

Blockout is a free (GPL-3.0) time-blocking planner for macOS. You keep your tasks on one side and your calendar on the other; dragging a task onto the calendar reserves that time as a busy event in your own calendar (any account added to macOS Calendar, such as Google), so other people see you as busy right away.

## Features

- **Tasks and projects** with native fields: urgency (`!`, `!!`, `!!!`), estimate, due date, status, notes, source and an external reference link. Completed tasks are hidden; the check icon above the input shows them (uncheck one to reopen it). Completing a task keeps all its blocks: the ones that have started become locked (translucent, dashed outline and a check mark, "Completado" in the legend) and cannot be moved or resized, only deleted; future blocks stay editable. Creating a new block for a completed task reopens it to "Por hacer". A task that an automation reopens through the MCP shows a "Reabierto" badge (hover it for the date) until it is completed again. Right-click a task to open it, change its urgency or delete it (with confirmation; its blocks and calendar events are deleted too). Create projects with "+" next to Proyectos; right-click a project › Editar… to change its name or color.
- **One input to filter and create**: typing filters the list; Enter creates a task. A trailing `2h` sets the estimate, a trailing `!!` sets the urgency, and an existing project name in the text assigns the project.
- **Quick-add bar**: a global shortcut (default ⌃⌥⇧⌘T, what a "Hyper" key sends with T) opens a floating input over any app, even with the Blockout window closed. It reads the text like the list input, creates the task on Enter and returns you to the previous app; Esc or clicking outside closes it. Change or remove the shortcut in Settings › Atajos.
- **Sidebar filters**: Todas, Hoy (tasks with a block today), Sin agendar, Agendadas, Vencidas, Reabiertas, Completadas, plus one filter per project and per source.
- **Calendar** in Día, Días (2 to 7), Semana and Mes views, showing the macOS calendars you choose, the free time per day and a red current-time line.
- **Blocks are real events**: dropping a task creates an event in the destination calendar at once, titled "[Proyecto] Título" (the task keeps its own title). Renaming the task or its project updates all its events. Move, resize, Option-drag to duplicate, or drag back to the list to unschedule. Changes made in Calendar or on the web are reflected back. "+ Agendar sesión" in the task detail books one block of the default length in the first free slot from the next quarter hour today, or in the following working days (up to two weeks); it works on done tasks too and reopens them to "Por hacer".
- **Local MCP server** for AI agents and automations (for example Claude or your own scripts) to read and change projects, tasks, the schedule and blocks.
- **Draft plans**: an agent can propose blocks; they appear hatched with a banner to accept or discard all, or one by one. Nothing reaches the calendar until you accept.
- **Time tracking**: start the timer from the menu bar or the task detail. Blockout sends no notifications. The menu bar shows the running time and a native menu with Completar, +15 min, Pausar and Detener, and the rest of the day. "+15 min" extends the current block and moves the following blocks around your meetings; blocks that no longer fit return to "Sin agendar". Recorded time is editable in each task. AI agents can record their own work sessions through the MCP; entries may overlap (parallel sessions count fully) and show their note and origin in the task.
- Light and dark appearance following the system.

## Requirements

- macOS 15 or later (Apple silicon or Intel).
- Xcode command line tools with Swift 6.
- A calendar account added to macOS Calendar (for example Google) to receive the blocks. Use an account calendar, not "On My Mac", so other people can see the busy time.

## Install

1. Download `Blockout-<version>.dmg` from the [latest release](https://github.com/nanoarmando/blockout/releases/latest).
2. Open it and drag Blockout to Applications.
3. Blockout is self-signed, not notarized, so clear the quarantine flag once:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Blockout.app
   ```

Later versions install from Acerca de Blockout › Instalar actualización.

## Build and run

```sh
Scripts/build.sh            # builds dist/Blockout.app (universal, signed)
Scripts/build.sh --install  # also copies it to /Applications
open dist/Blockout.app
```

For quick development builds, `swift build` compiles the binary without assembling the app bundle.

### Signing identity

Blockout is signed with a stable self-signed identity called `Blockout Self-Signed`, so macOS remembers the Calendar permission across rebuilds. Without it, the script signs ad hoc and macOS asks for the permission again after every build. Create the identity once per Mac:

```sh
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout /tmp/blockout-key.pem -out /tmp/blockout-cert.pem \
  -subj "/CN=Blockout Self-Signed" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"

openssl pkcs12 -export -inkey /tmp/blockout-key.pem -in /tmp/blockout-cert.pem \
  -name "Blockout Self-Signed" -out /tmp/blockout.p12 -passout pass:blockout

security import /tmp/blockout.p12 -k ~/Library/Keychains/login.keychain-db \
  -P blockout -A -T /usr/bin/codesign

rm -f /tmp/blockout-key.pem /tmp/blockout-cert.pem /tmp/blockout.p12
```

If `security import` rejects the `.p12` with a MAC verification error, add `-legacy` to the `openssl pkcs12` line. To use another identity, set `BLOCKOUT_SIGN_IDENTITY`.

Maintainers: keep a backup of the `.p12` (before deleting it) in a safe place. Installed copies only accept updates signed with the same certificate; a new identity forces every user to reinstall manually.

## Permissions

On first launch Blockout asks for full access to your calendars. If you deny it, tasks keep working and the calendar area offers a button to open System Settings › Privacy & Security › Calendars.

Closing the window keeps Blockout running in the menu bar (the timer and the MCP server need it). Quit with ⌘Q.

## Key concepts

- **Destination calendar**: the calendar where blocks are written, as busy (default) or free events. Choose it in Settings.
- **Calendars that are read**: the calendars shown in the views and counted against free time. Choose them in Settings › Elegir….
- **Working hours and block length**: set in Settings. New blocks use the block length setting (30 or 60 minutes); the estimate is only a guide unless you choose "Según la estimación". They land exactly where you drop them, in 15-minute steps inside the working hours; if that time overlaps a meeting or another block, the drop is refused with a message. Events marked as free (available) in your calendar do not count as busy.
- **Data**: everything stays on your Mac (`~/Library/Application Support/Blockout`). No accounts and no telemetry.

## Privacy

Blockout only uses the network to check for updates: one request to the public GitHub Releases API (`api.github.com/repos/nanoarmando/blockout/releases/latest`) at launch, once a day and when Acerca de Blockout opens, without any user data, plus the DMG download when you choose to install. The MCP server listens only on your Mac.

## Updates

When a newer release exists, "Actualización disponible" appears in the app menu and the menu bar menu. Acerca de Blockout shows the release notes and "Instalar actualización", which downloads the DMG, checks that the new app is signed with the same certificate and has the announced version, asks for confirmation, replaces the app and reopens it. If any check fails, the installed app is not changed. Installing is disabled while a timer runs and in ad hoc signed builds. Data, settings and permissions are kept.

## MCP server

While Blockout is open, it serves the Model Context Protocol at `http://127.0.0.1:43219/mcp` (HTTP JSON-RPC, no sessions, loopback only). Settings › Integraciones shows its state, lets you copy the address, change the port or turn it off.

| Tool | What it does |
|---|---|
| `list_projects`, `create_project` | List projects; creating an existing name (any case) returns the existing one. |
| `list_tasks` | Tasks with native fields, blocks, drafts and scheduled state. Filters: `status`, `project`, `include_done`. |
| `create_task`, `update_task` | Every task field, including `external_ref {label, id, url}`. Create returns the existing task for an open task with the same title or any task with the same external reference, unless `allow_duplicate` is true. `update_task` also accepts `reopened` (true marks an open task as reopened; false or null removes the mark), and every task in tool output includes `reopened_at`. |
| `delete_task`, `delete_block` | Without `confirm: true` they only return what would be deleted. |
| `get_schedule` | Events, blocks, drafts, working hours and free time for up to 31 days. |
| `schedule_task`, `update_block` | Create or change a block and its calendar event at once; a busy start moves to the next free slot. Scheduling a done task reopens it; `update_block` rejects locked blocks (every block in output has `locked`). |
| `propose_blocks` | Create draft blocks for review; items that do not fit are rejected with a reason. A new proposal replaces the previous drafts. |
| `list_time_entries` | Recorded time between two dates, with task, project, source and external reference, plus `key`, `note` and `origin` for agent entries, for time reports. Blockout has no report view: ask an agent for weekly totals. |
| `upsert_time_entry` | An agent records a closed entry (`key`, `task_id`, `start`, `end`, optional `note` and `origin`). Sending the same key again replaces the entry (extend, correct or move it to another task). Never affects the running timer. |
| `delete_time_entry` | Deletes the entry with a `key`; without `confirm: true` it only returns what would be deleted. |

Example:

```sh
curl -s http://127.0.0.1:43219/mcp -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_tasks","arguments":{}}}'
```

To use it from Claude Code: `claude mcp add --transport http blockout http://127.0.0.1:43219/mcp`.

Any process on your Mac can call the server while it is on; turn it off in Settings if you do not use it.

## Releases (maintainers)

1. Bump `VERSION`, commit and push.
2. Build the DMG: `Scripts/build-dmg.sh <version>`. It refuses to run when the version does not match `VERSION` or the `Blockout Self-Signed` identity is missing, and writes `dist/Blockout-<version>.dmg`.
3. Publish: `gh release create v<version> dist/Blockout-<version>.dmg --title "Blockout <version>" --notes-file <notes>`. The asset name must be exactly `Blockout-<version>.dmg`.

## Status

The plan lives in `openspec/changes/`, in four stages plus later changes:

1. `add-planner-core`: tasks, projects and the calendar planner (implemented, pending manual verification).
2. `add-mcp-server`: local MCP server for AI agents and automations, and draft plans to accept or discard (implemented, pending manual verification).
3. `add-time-tracking`: a timer in the menu bar and editable time entries (implemented, pending manual verification).
4. `add-public-release`: signed DMG releases on GitHub and in-app updates (released as 1.0.0).
5. `add-reopened-badge`: "Reabierto" badge and "Reabiertas" filter for tasks that an automation reopens through the MCP (released as 1.0.6).
6. `add-agent-time-entries`: agents record, extend and delete their own time entries through the MCP (implemented, pending manual verification).
7. `add-schedule-session`: "+ Agendar sesión" replaces "+ Agendar las horas restantes" in the task detail (implemented, pending manual verification).
8. `add-quick-add-hotkey`: global shortcut and floating quick-add bar, configurable in Settings › Atajos (implemented, pending manual verification).
9. `remove-block-prompts`: block start and end notifications removed; leftovers are cleared at launch (implemented, pending manual verification).
10. `keep-completed-task-blocks`: completing a task keeps its blocks and locks the started ones; new blocks reopen it (implemented, pending manual verification).

## Roadmap

- **Multiple languages**: the interface is currently in Spanish only, with texts written directly in the code. Planned: a String Catalog (`Localizable.xcstrings`) with Spanish as the default language plus English, dates following the system language, and translated texts built outside SwiftUI views (formats, errors, status labels).

## License

[GPL-3.0](LICENSE).
