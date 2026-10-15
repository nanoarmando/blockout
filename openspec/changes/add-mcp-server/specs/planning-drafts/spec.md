## Purpose

Lets an agent propose a plan as draft blocks that the user reviews in Blockout, so nothing reaches the real calendar without the user's consent.

## ADDED Requirements

### Requirement: Propose drafts
The server SHALL provide `propose_blocks` with a list of {task, start, length}. Each item SHALL become a draft block when it fits inside working hours without overlapping events, blocks or other items of the same proposal; items that do not fit SHALL be rejected individually with the reason. A new proposal SHALL replace the drafts of the previous one. Drafts SHALL NOT create calendar events.

#### Scenario: Partial proposal
- **WHEN** an agent proposes three items and one overlaps a meeting
- **THEN** two drafts are created and the response explains why the third was rejected

#### Scenario: No calendar writes
- **WHEN** drafts exist
- **THEN** the destination calendar has no events for them

### Requirement: Review drafts in the app
While drafts exist, the calendar SHALL show them with a hatched fill and dashed outline, and a banner SHALL state how many blocks are proposed with "Aceptar todo" and "Descartar". Selecting a single draft SHALL offer accepting or discarding only that one. Accepting SHALL turn drafts into blocks and write their events immediately; discarding SHALL remove them.

#### Scenario: Accept all
- **WHEN** the user activates "Aceptar todo" with three drafts
- **THEN** three blocks exist, their busy events are in the calendar, the tasks move to "Agendadas" and the banner disappears

#### Scenario: Conflict at acceptance
- **WHEN** a meeting was added after the proposal and now overlaps a draft
- **THEN** accepting skips that draft, keeps it visible and tells the user which one could not be placed
