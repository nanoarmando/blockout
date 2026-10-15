## Why

Blockout must replace Anchor in the author's daily flow, where tasks arrive automatically from meetings and tickets through a separate automation tool, and AI agents (Claude) plan the day on request. Both need a programmatic interface. Exposing native fields (urgency, estimate, external reference, scheduled state) removes the title conventions that Anchor forced.

## What Changes

- Local MCP server inside Blockout (HTTP JSON-RPC on 127.0.0.1, stateless, can be turned off) with tools for projects, tasks, schedule, blocks and drafts.
- Draft blocks ("borradores"): an agent proposes blocks; Blockout shows them hatched with a banner to accept or discard all, or one by one; nothing reaches the calendar until accepted.
- Settings section for the MCP server: on/off, address with a copy button, status.
- Migration of the author's external automation (separate repository) from Anchor to Blockout, keeping every rule agreed for Anchor and replacing the title conventions with native fields; the ticket tag becomes a setting of the automation with default "Blockout".

## Capabilities

### New Capabilities
- `mcp-server`: transport, availability and the tool contract for projects, tasks, schedule and blocks.
- `planning-drafts`: proposing, showing, accepting and discarding draft blocks.

### Modified Capabilities

None (`add-planner-core` is not archived yet; this change only adds capabilities).

## Impact

- Blockout: new MCP server component and settings section; draft state in the data model (schema version 2).
- External automation (separate repository): rewritten writes and reads against the Blockout MCP, new setting for the Odoo tag, Anchor removed. Ships as a new release of the automation.
- Depends on `add-planner-core`.
