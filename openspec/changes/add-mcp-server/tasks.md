## 1. Server

- [x] 1.1 Implement the loopback HTTP JSON-RPC listener with `initialize`, `tools/list` and stateless `tools/call` (D1; mcp-server)
- [x] 1.2 Add the MCP settings section: switch, port, state (active, off, port busy) and copy address
- [x] 1.3 Implement tool error handling with `isError` and unchanged data on failure

## 2. Tools

- [x] 2.1 `list_projects`, `create_project` with case-insensitive reuse
- [x] 2.2 `list_tasks`, `create_task` (title and external-reference dedupe, `allow_duplicate`), `update_task`, `delete_task` with confirmation (D3)
- [x] 2.3 `get_schedule` with events, blocks, drafts, working hours and free time
- [x] 2.4 `schedule_task`, `update_block`, `delete_block` with confirmation, through `CalendarService` (D2)

## 3. Drafts

- [x] 3.1 Add block state and proposal id (schema v2 migration) (D4)
- [x] 3.2 `propose_blocks` with per-item validation and replacement of previous drafts (planning-drafts)
- [x] 3.3 Draft rendering, banner with "Aceptar todo"/"Descartar", per-draft accept/discard and conflict handling at acceptance

## 4. External automation migration (separate repository)

- [x] 4.1 Add a ticket tag setting (default "Blockout") to the automation (D5)
- [x] 4.2 Rewrite the automation's writes and reads against the Blockout MCP with native fields and `external_ref`, keeping every rule in D5 and removing the title-convention and 📅 steps
- [x] 4.3 Add the one-time import of open Anchor tasks into Blockout
- [x] 4.4 Update the automation's docs and publish its release

## 5. Docs and verification

- [x] 5.1 Document the MCP tools and setup in Blockout's README and AGENTS
- [ ] 5.2 Verify every scenario of both specs with `curl`, then run the automation end to end against Blockout (meeting, new Odoo ticket, matched ticket, waiting stage, untagged ticket, user-completed task)
