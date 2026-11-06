## 1. Behavior

- [x] 1.1 Delete the block notification service and its startup wiring and environment injection (No block notifications; Delete StartPrompts instead of disabling it)
- [x] 1.2 Remove pending and delivered notifications at launch without requesting authorization (Clean up earlier notifications)

## 2. Interface

- [x] 2.1 Remove the "Notificaciones desactivadas" warning, "Abrir Ajustes" and the prompt fallback from the menu bar menu, keeping the timer controls (No notification permission)

## 3. Docs and verification

- [x] 3.1 Update `README.md` (time tracking, permissions) and `AGENTS.md` (structure, contracts)
- [ ] 3.2 Verify with a debug build that no notification appears at block start or end and that the menu shows no warning
