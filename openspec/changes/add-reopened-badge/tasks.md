## 1. Data model

- [x] 1.1 Add schema version 4 with an optional `reopenedAt` date on tasks, a lightweight 3→4 migration stage, and repoint the typealiases and the container (Reopened mark set by agents)

## 2. Behavior

- [x] 2.1 Clear `reopenedAt` in the shared completion function (Mark removed on completion)
- [x] 2.2 Parse the optional `reopened` argument in `update_task`, apply it after the status, ignore it when the task ends done, and ignore it in `create_task` (Reopened mark set by agents)
- [x] 2.3 Add `reopened_at` to the task JSON output and document `reopened` and `reopened_at` in the tool definitions (Reopened mark in tool output)

## 3. Interface

- [x] 3.1 Add a reusable "Reabierto" badge with a date tooltip and show it in the task row (counted as row metadata) and in the task detail header (Reopened badge)
- [x] 3.2 Add the "Reabiertas" sidebar filter after "Vencidas" with its count (Reopened filter)

## 4. Docs and verification

- [x] 4.1 Update `README.md` (filters, MCP) and `AGENTS.md` (schema version 4, MCP contract)
- [x] 4.2 Verify every scenario with a debug build on a scratch store (`BLOCKOUT_STORE_DIR`) and `curl` against the MCP, including migration of an existing version 3 store
