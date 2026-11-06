## 1. Data model

- [x] 1.1 Add schema version 5 with optional `key`, `note` and `origin` on time entries, a lightweight 4→5 migration stage, and repoint the typealiases and the container (New schema version 5)

## 2. Behavior

- [x] 2.1 Add upsert-by-key and delete-by-key methods to the timer service that never touch the running pointer, and pass the service to the MCP tools at startup (Writes live in the timer service; Overlapping entries)
- [x] 2.2 Add `upsert_time_entry`: validate key, task, start and end before mutating, create or fully replace the entry, return the entry and `created` (Record time entries from agents; Update an entry by key; Agent entries need a task and a closed range)
- [x] 2.3 Add `delete_time_entry` with the `confirm` pattern and an error for unknown keys (Delete an entry by key)
- [x] 2.4 Extract one entry JSON helper, add `key`, `note` and `origin` to it, and use it in the three time-entry tools (Agent fields in list_time_entries)
- [x] 2.5 Add both tool definitions and update the `list_time_entries` description (Record time entries from agents; Delete an entry by key)

## 3. Interface

- [x] 3.1 Show note and origin as a secondary line under each entry row in the task detail when present (Note and origin in the task detail)

## 4. Docs and verification

- [x] 4.1 Update `README.md` (MCP tools, status) and `AGENTS.md` (schema version 5, time-tracking and MCP contracts)
- [ ] 4.2 Verify every scenario with a debug build on a scratch store (`BLOCKOUT_STORE_DIR`) and `curl` against the MCP, including migration of an existing version 4 store
