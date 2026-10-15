## Purpose

Gives quick, native access to the current block and the timer from the macOS menu bar without opening the main window.

## ADDED Requirements

### Requirement: Menu bar item
Blockout SHALL show a menu bar item with its icon; while a timer runs, it SHALL also show the elapsed time and a short task name, updated at least every minute.

#### Scenario: Timer running
- **WHEN** a timer has run for 24 minutes on "Checkout - Personalizaciones por país"
- **THEN** the item reads "0:24 Checkout…"

### Requirement: Native menu content
Clicking the item SHALL open a native macOS menu (system material, font and separators) showing: the current or next block with its task, range, project and external reference; the timer actions that apply (Empezar; or Completar, +15 min, Pausar/Reanudar and Detener; or Retomar after stopping); a "Después" section with the rest of today's blocks and events in time order, marking shifted blocks as "antes → ahora"; and "Abrir Blockout" (⌘O) and "Ajustes…" (⌘,). It SHALL NOT include task creation.

#### Scenario: Stopped timer
- **WHEN** the user chooses "Detener"
- **THEN** the entry is saved, the menu shows "Detenido" with the recorded time and offers "Retomar"

#### Scenario: Completing from the menu
- **WHEN** the user chooses "Completar"
- **THEN** the timer stops, the entry is saved and the task is completed under the planner's completion rules
