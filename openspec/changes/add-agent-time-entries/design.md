## Context

See proposal.md - Why. Time entries are a SwiftData model with a task, a start and an optional end; the only invariant is "at most one running entry", enforced by the timer service through its own pointer, and at launch it closes every entry left without an end. The MCP server handles one request at a time on the main actor, shares the app's model context, and every write tool validates all arguments before mutating. Task totals are a plain sum of entry minutes. There is no time-report view by design.

## Goals / Non-Goals

**Goals:** let agents write, extend, move and delete their own closed entries idempotently; keep `list_time_entries` backward compatible; show the agent's note in the app.

**Non-Goals:** entries without a task, open (running) agent entries, merging overlaps in totals, a time-report view, deciding which task an agent's work belongs to (that belongs to each agent), editing note or origin in the app.

## Decisions

- **Closed entries only.** `end` is required. An open entry written from outside would break the one-running invariant and be closed at its start on the next launch. Agents extend an entry by upserting the same key with a later end.
- **Key unique across all entries, checked in code.** A fetch by key followed by insert or update runs inside one main-actor handler, so concurrent sessions cannot race. No unique attribute in the schema: it would add migration risk for no gain, and project names already follow this pattern.
- **A repeated key moves the entry.** Upsert replaces every field, including the task, so an agent corrects a wrong task in one call. Alternative: reject a task change; rejected because it forces a delete and a create for the same correction.
- **Full replace on update.** Omitted `note` or `origin` are cleared, so the result never mixes two writes. Agents always send the full segment.
- **Field named `origin`, not `source`.** `list_time_entries` already returns `source` as the task's source label; reusing the name would break existing consumers.
- **Plain sum for totals.** Overlap from parallel sessions counts fully, as the user chose; no change to the total computation.
- **New schema version 5 with a lightweight migration**, adding optional `key`, `note` and `origin` to time entries. Shipped versions are never edited in place.
- **Writes live in the timer service.** The service is the single owner of time-entry writes; the MCP tools receive it at startup and call its new upsert and delete-by-key methods. Agent entries never touch the timer's running pointer.
- **One entry encoder.** `list_time_entries`, `upsert_time_entry` and `delete_time_entry` return entries through the same JSON helper.
- **Delete requires `confirm: true`**, consistent with the other delete tools; any local process can call the MCP.
- **Note and origin as one secondary line** under the time row in the task detail, read-only, using existing secondary text styling.

## Risks / Trade-offs

- [Overlap inflates totals] → accepted by the user; `list_time_entries` exposes start and end so a report can still compute wall-clock time if needed.
- [An entry extended past midnight is listed only under its start day] → same as timer entries today; agents can split segments per day.
- [Deleting a task deletes its agent entries] → existing cascade rule; a later upsert with that key creates a new entry.
- [An agent calls the new tools on an older Blockout] → the call fails with an unknown-tool error and nothing is written. Mitigation: release Blockout first, then the agent setup.

## Migration Plan

Ship a Blockout release with schema version 5 (lightweight migration from 4). Then enable the agent-side setup that calls the new tools. Rollback: an older app build cannot open a store migrated to version 5, so roll back only by installing this release again or later.
