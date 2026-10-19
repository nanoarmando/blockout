## Context

See proposal.md - Why. Tasks have no completion timestamp. Every completion path (list, detail, timer, MCP) already converges on one function that removes future blocks and sets the status to done; manual reopen sets the status directly. The MCP parses optional fields with a "key absent vs null" pattern and returns tasks through one JSON encoder. Sidebar filters are one enum with a `matches` rule and a fixed list of labels.

## Goals / Non-Goals

**Goals:** one optional field, one place that clears it, additive MCP contract.

**Non-Goals:** reopen history or counts, notifications, a `list_tasks` filter by mark, deciding when an external item "returned" (that belongs to each automation).

## Decisions

- **Store a date, not a boolean** (`reopenedAt: Date?`). It powers the badge tooltip at no extra cost. Alternative: boolean only; rejected because the date is useful and costs the same.
- **New schema version with a lightweight migration.** Shipped versions are never edited in place; an optional field migrates without custom code.
- **Agents send a boolean, the app stamps the time.** `reopened: true` lets the app use its own clock and keeps automations free of date formatting. Alternative: accept a timestamp; rejected (YAGNI).
- **The flag is applied after the status.** If the resulting task is done, `reopened: true` is ignored, so a single call can never leave a done task marked.
- **Clear in the shared completion function.** All completion paths already pass through it, so the rule lives in one place.
- **Accept `reopened` in `update_task` only.** A task created by `create_task` was never completed, so marking it would be meaningless; `create_task` ignores the key.
- **Small reusable badge view** next to the existing project chip, using the existing accent colors. No new color tokens.

## Risks / Trade-offs

- [An automation sends `reopened` to an older Blockout] → older versions ignore unknown keys, so the task reopens without a badge. Mitigation: release Blockout first, then the automation.
- [Forgetting to register the new schema version] → the store fails to open. Mitigation: task list covers the migration plan, the typealiases and the container.

## Migration Plan

Ship a Blockout release with schema version 4 (lightweight migration from 3). Then release the external automation that sends `reopened: true`. Rollback: an older app build cannot open a store migrated to version 4, so roll back only by installing this release again or later.
