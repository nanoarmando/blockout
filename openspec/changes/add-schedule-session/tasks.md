## 1. Behavior and interface

- [x] 1.1 Replace the remaining-hours button with an always-visible "+ Agendar sesión" button, keep the scheduled summary, and remove the unused remaining-minutes value (Schedule a session from the task detail)
- [x] 1.2 Make the action use the settings' per-task block length with the existing two-week slot search and error, without touching the task's status (Session length and placement; Sessions on done tasks)

## 2. Docs and verification

- [x] 2.1 Update `README.md` and `AGENTS.md` mentions of "Agendar las horas restantes"
- [ ] 2.2 Verify every scenario with a debug build on a scratch store (`BLOCKOUT_STORE_DIR`) and a test calendar, including a done task and a day with no time left
