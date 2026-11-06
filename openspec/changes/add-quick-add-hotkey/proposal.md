## Why

Creating a task today requires bringing the Blockout window forward and typing in the list's input. Tasks come up while working in other apps, and switching windows breaks focus. A global shortcut that opens only a small floating input, like a launcher bar, lets the user capture a task in a second and return to what they were doing.

## What Changes

- A global keyboard shortcut opens a floating quick-add bar over any app, even while the Blockout window is closed. The default shortcut is Ctrl+Option+Command+Shift+T (what a "Hyper" key sends with T).
- The bar parses text exactly like the list's input (project name, "2h" estimate, `!`/`!!`/`!!!` urgency), shows the same "↵ Crear «…» en <proyecto>" hint, creates the task on Enter, then closes and returns focus to the previous app. Esc or clicking outside closes it without creating anything.
- Settings gain an "Atajos" section with a shortcut recorder to change or clear the shortcut; clearing it disables the feature. If the shortcut cannot be registered (for example, another app owns it), Settings says so.

## Capabilities

### New Capabilities
- `quick-add-hotkey`: the global shortcut, the floating quick-add bar, and the shortcut setting.

### Modified Capabilities

None (`add-planner-core` is not archived yet; the bar reuses its task-creation parsing without changing it).

## Impact

- App: new floating panel and hotkey owner created at startup; Settings view; settings model (new optional field with a default).
- Uses the macOS Carbon hotkey API (system framework, no new dependency, no Accessibility permission).
- Docs: `README.md` (usage, settings) and `AGENTS.md` (structure, contracts).
- Depends on `add-planner-core`.
