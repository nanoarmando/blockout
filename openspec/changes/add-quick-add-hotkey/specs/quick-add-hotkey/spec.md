## ADDED Requirements

### Requirement: Global shortcut opens the quick-add bar
While Blockout runs, pressing the configured shortcut in any app SHALL open a floating quick-add bar with its input focused, centered horizontally near the top of the active screen, above other windows, even when the Blockout window is closed. It SHALL NOT open the Blockout window. Pressing the shortcut while the bar is open SHALL close it. The default shortcut SHALL be Ctrl+Option+Command+Shift+T.

#### Scenario: Open from another app
- **WHEN** the user is in another app with the Blockout window closed and presses Ctrl+Option+Command+Shift+T
- **THEN** the quick-add bar appears with the cursor in its input and the Blockout window stays closed

#### Scenario: Toggle
- **WHEN** the bar is open and the user presses the shortcut again
- **THEN** the bar closes without creating anything

### Requirement: Create a task from the bar
The bar SHALL interpret its text with the same rules as the list's filter-and-create input (project detection, estimate, urgency) and SHALL show the same "↵ Crear «…» en <proyecto>" hint while the user types. Enter with non-empty text SHALL create the task, close the bar and return focus to the previously active app. Enter with empty text SHALL do nothing. If the task cannot be saved, the bar SHALL stay open with its text and show the error inside the bar.

#### Scenario: Create with project and estimate
- **WHEN** the user types "Revisar sync de acme 2h !!" in the bar, the project "Acme" exists, and presses Enter
- **THEN** a task "Revisar sync de acme" is created in Acme with estimate 2h and medium urgency, the bar closes, and the previous app is active again

#### Scenario: Empty input
- **WHEN** the bar's input is empty or only spaces and the user presses Enter
- **THEN** nothing is created and the bar stays open

### Requirement: Dismiss the bar
Esc, or moving focus away from the bar (for example, clicking outside), SHALL close the bar without creating a task and SHALL clear its text, so it opens empty the next time.

#### Scenario: Escape
- **WHEN** the user types "Algo" and presses Esc
- **THEN** the bar closes, no task is created, and it opens empty next time

### Requirement: Shortcut setting
Settings SHALL include an "Atajos" section with a "Nueva tarea" shortcut recorder showing the current shortcut. Recording a new combination SHALL replace the shortcut immediately and persist it across launches. A combination SHALL include at least one of Command, Option or Control plus one non-modifier key; other combinations SHALL be rejected. Clearing the shortcut SHALL disable the global shortcut. When the shortcut cannot be registered, Settings SHALL show that it is unavailable and the previous shortcut SHALL stay active.

#### Scenario: Change shortcut
- **WHEN** the user records Option+Command+N
- **THEN** Option+Command+N opens the bar, Ctrl+Option+Command+Shift+T no longer does, and the choice survives a restart

#### Scenario: Clear shortcut
- **WHEN** the user clears the shortcut
- **THEN** no global shortcut opens the bar until a new one is recorded

#### Scenario: Shortcut in use
- **WHEN** the user records a combination that macOS refuses to register
- **THEN** Settings says the shortcut is not available and the previous shortcut keeps working

#### Scenario: Missing modifier
- **WHEN** the user tries to record a single letter without Command, Option or Control
- **THEN** the combination is rejected and the current shortcut is kept
