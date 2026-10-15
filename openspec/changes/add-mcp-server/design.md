## Context

See proposal.md. The planner core (`add-planner-core`) owns tasks, projects, blocks and the calendar service. The author's external automation already talks to Anchor's MCP with stateless `curl` JSON-RPC calls; Blockout keeps that style so the migration is mostly a contract swap.

## Goals / Non-Goals

**Goals:** an MCP contract rich enough that automations and AI agents never encode data in titles; review-before-write planning.

**Non-Goals:** authentication tokens, remote access, Streamable HTTP sessions/SSE, time-entry tools (stage 3), an in-app "plan with Claude" button (decided: planning is requested from the chat only).

## Decisions

### D1. Minimal HTTP server on `Network.framework`
An `NWListener` bound to `127.0.0.1` parses HTTP/1.1 POST `/mcp`, answers JSON (no SSE), supports `initialize`, `tools/list` and `tools/call`. Alternative: a third-party Swift MCP SDK — heavier and session-oriented; the stateless subset is small. Port 43219 avoids Anchor's 43117 during the transition.

### D2. Tools run on the main actor through the same services as the UI
Tool handlers call the same task store, `CalendarService` and `SlotFinder` as the views, so MCP and UI rules cannot diverge (DRY). Results are JSON text content, mirroring Anchor's shape where it helps existing clients (`{"tasks":[…]}`).

### D3. External reference as structured field
`external_ref = {label, id, url}` plus `source`. Dedupe by (label prefix/source, id) covers done tasks, which is what an automation needs to never re-create a ticket's task.

### D4. Drafts as a block state
`Block.state = draft | confirmed` (schema v2) with a `proposalId`; drafts are excluded from calendar writes and from free-time counting for other drafts' validation only within the same proposal.

### D4b. Placement and free-time clarifications (approved)
`schedule_task` uses `SlotFinder` like a drop: an occupied start moves to the next free slot of that day, the result returns the actual start and end, and the call fails when nothing fits. Drafts do not reduce the free time shown in day headers or returned by `get_schedule`, because they are not real reservations.

### D5. External automations (separate repository)
The author's private automation tool moves from Anchor to Blockout: it creates tasks from meeting notes and from tagged tickets of a ticketing system using native fields (project, urgency, estimate, due date, `source`, `external_ref`) instead of title conventions, links tickets to existing tasks through `external_ref`, syncs ticket status without reopening tasks the user completed, and fails before doing any work when Blockout is not reachable. Its rules live in that repository, not in Blockout.

## Risks / Trade-offs

- [Any local process can call the server] → loopback only, can be turned off; a token can be added later without breaking clients.
- [Model-proposed plans conflict with late calendar changes] → validation at proposal and again at acceptance.
- [Automation and Blockout releases must line up] → the automation checks for the Blockout MCP and fails with a clear message, so an old Blockout is visible, not silent.

## Migration Plan

1. Release Blockout with the MCP. 2. Release the automation with the Blockout migration (one-time import of open Anchor tasks: create in Blockout with native fields from the existing prefixes and links). 3. Stop using Anchor. Rollback: install the previous automation release; Anchor data is untouched by the import.
