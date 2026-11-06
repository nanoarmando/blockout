## ADDED Requirements

### Requirement: No block notifications
Blockout SHALL NOT show any notification or menu prompt when a block starts or ends, whether or not a timer runs. This replaces the "Start prompt" and "End prompt" requirements of time tracking.

#### Scenario: Block starts
- **WHEN** a block starts and no timer runs
- **THEN** no notification appears and the menu bar menu shows no prompt for it

#### Scenario: Timed block ends
- **WHEN** the timer runs for a task and its block reaches its end
- **THEN** no notification appears and the timer keeps running

### Requirement: No notification permission
Blockout SHALL NOT ask for notification permission, and the menu bar menu SHALL NOT show "Notificaciones desactivadas" or "Abrir Ajustes".

#### Scenario: Notifications off
- **WHEN** notifications for Blockout are off in macOS and the user opens the menu bar menu
- **THEN** the menu shows no notification warning

### Requirement: Clean up earlier notifications
On launch, Blockout SHALL remove its pending and delivered notifications scheduled by earlier versions.

#### Scenario: Update with pending prompts
- **WHEN** the user updates from a version that had scheduled prompts for today's blocks
- **THEN** none of those prompts appears after the update
