## 1. Data model

- [x] 1.1 Add schema version 6 with `locked` on blocks, a custom 5→6 stage that locks started confirmed blocks of completed tasks, and repoint the typealiases and the container (Existing completed tasks; Schema version 6)

## 2. Behavior

- [x] 2.1 Change `markDone` to keep every confirmed block, lock the started ones, and still delete the task's drafts (Completion keeps every block; Completion locks worked blocks)
- [x] 2.2 Reopen a done task to todo without the reopened mark when `insertBlock` or draft acceptance creates a block for it (New blocks reopen completed tasks)
- [x] 2.3 Reject moving or resizing locked blocks in the calendar service and in MCP `update_block` (Locked blocks cannot be moved or resized)
- [x] 2.4 Skip locked blocks in the "+15 min" cascade, keeping them in busy time (Locked blocks in scheduling)
- [x] 2.5 Add `locked` to the block JSON and update the `update_task`, `update_block` and `schedule_task` descriptions (Lock in MCP output)

## 3. Interface

- [x] 3.1 Remove drag, Option-drag and resize from locked blocks, and ignore locked payloads in the day column and list drop targets (Locked blocks cannot be moved or resized)
- [x] 3.2 Add the completed style to the time grid and month view, show the check mark only on locked blocks, and add "Completado" to the legend (Completed style)

## 4. Related change and docs

- [x] 4.1 Update `add-schedule-session`'s "Sessions on done tasks" requirement and design note to the reopen rule (Supersede add-schedule-session)
- [x] 4.2 Update `README.md` and `AGENTS.md` (completion rule, reopen on new blocks, schema version 6, MCP contract)
- [ ] 4.3 Verify every scenario with a debug build on a scratch store and a test calendar, including the upgrade of a version 5 store
