## Why

The author logs hours in Odoo and needs to know where the time actually went. Blocks show the plan, not the reality. Blockout should record real working time per task with minimal friction and expose it so an agent can produce a weekly report to copy into Odoo (the Odoo MCP is read-only, so hours are entered by hand).

## What Changes

- At the start of each block, a macOS notification asks "¿Estás trabajando en esto?" with "Sí, empezar", "En 5 min" and "Saltar".
- A menu bar item shows the running timer; its native menu shows the current task with Completar, +15 min, Pausar/Reanudar and Detener/Retomar, the "Después" list of the day, and Abrir Blockout / Ajustes….
- "+15 min" extends the current block and shifts the following blocks of the day in cascade; calendar events never move; blocks that no longer fit return to "Sin agendar".
- Time entries are stored per task; the task detail lists them as editable (start, end), allows deletion and manual entries, and can resume the timer.
- MCP tool `list_time_entries` for a date range, for reports.
- No time-report view in the app (decided).

## Capabilities

### New Capabilities
- `time-tracking`: the start prompt, the timer, time entries and their editing.
- `menu-bar`: the menu bar item and its native menu.
- `block-extension`: extending the current block and the cascade rules.

### Modified Capabilities

None (`add-mcp-server` is not archived yet; the new tool is specified under `time-tracking`).

## Impact

- Blockout: notification permission, menu bar extra, time-entry model (schema version 3), one new MCP tool.
- Depends on `add-planner-core` and `add-mcp-server`.
