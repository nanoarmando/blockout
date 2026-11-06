## Why

The block notifications ("¿Estás trabajando en esto?" at block start and "¿Terminaste esta tarea?" at block end) do not work reliably in practice and the user finds them redundant: time is now recorded by agents and by the menu bar timer, and the menu bar already offers "Completar" and "+15 min".

## What Changes

- **BREAKING:** remove the start prompt (notification and its menu fallback, with "Sí, empezar", "En 5 min", "Saltar").
- **BREAKING:** remove the end prompt (notification with "Terminada" and "+15 min").
- Remove the "Notificaciones desactivadas" warning and "Abrir Ajustes" from the menu bar menu, and stop asking for notification permission.
- On launch, remove pending and delivered Blockout notifications left by earlier versions, so none fires after the update.
- The menu bar timer, "Completar", "+15 min", "Pausar" and "Detener" stay unchanged.

## Capabilities

### New Capabilities
- `block-prompts-removal`: the absence of block notifications and permission requests, and the cleanup of notifications left by earlier versions.

### Modified Capabilities

None (`add-time-tracking` is not archived yet; this change supersedes its "Start prompt" and "End prompt" requirements).

## Impact

- App: the notification service is removed, except a launch cleanup; menu bar menu; app startup.
- Docs: `README.md` (time tracking, permissions) and `AGENTS.md` (structure).
- Depends on `add-time-tracking`.
