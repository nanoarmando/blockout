## Context

See proposal.md - Why. Blockout is a Dock and menu bar app that keeps running after its window closes. The list's input creates tasks through a pure parser plus a model-context helper; nothing about it depends on the list view. Settings are one Codable struct saved as JSON, decoding each field with a default so older saves keep working, and the Settings view re-applies runtime configuration on change (as it does for the MCP server). The app is not sandboxed, uses the hardened runtime, targets macOS 15, and must not add third-party dependencies.

## Goals / Non-Goals

**Goals:** capture a task from anywhere in one shortcut and one Enter, reusing the existing parser and creation path; configurable shortcut without new permissions.

**Non-Goals:** editing other task fields in the bar, showing matching tasks, multiple shortcuts, opening the main window after creation.

## Decisions

- **Carbon `RegisterEventHotKey`.** Works in the background without Accessibility or Input Monitoring permission and consumes the key so the frontmost app does not receive it. Alternative: an `NSEvent` global monitor; rejected because it needs Accessibility permission and cannot swallow the key.
- **One hotkey owner created at startup** that registers the stored shortcut, re-registers when the setting changes, and reports registration failure to Settings. On failure it re-registers the previous combination.
- **Floating `NSPanel` hosting a SwiftUI view**: borderless, floating level, able to become key, shown on the screen with the mouse. The app is activated to take typing; after creating or dismissing, the panel hides and the app deactivates so the previous app regains focus. Losing key status closes the panel.
- **Reuse the creation path.** The bar calls the same parser and model-context helper as the list, fetching projects at submit time; the hint uses the same project detection. No duplicated parsing rules.
- **Errors inside the bar.** The main window may be closed, so its alerts are not visible; the bar shows the message in a line under the input.
- **Shortcut stored as key code plus modifier flags** in settings (optional field, default Ctrl+Option+Command+Shift+T; null means disabled), with the matching default in the decoder so existing saves get the default.
- **Small built-in recorder.** A field in Settings that, while focused, captures the next key event with a local monitor (no permission needed inside the app), validates the modifiers, and displays the combination with macOS symbols (⌃⌥⇧⌘T). A clear button sets it to disabled.

## Risks / Trade-offs

- [Another app owns the combination] → registration fails; Settings shows it and the previous shortcut stays.
- [Recording the current shortcut while it is registered] → the recorder pauses the global hotkey while it is focused, so the press reaches the field.
- [Hyper key remappers] → they send the four modifiers, which Carbon sees as a normal combination; no special handling.
- [Activation steals focus briefly] → returning focus by deactivating the app is the standard launcher behavior.

## Migration Plan

Settings gain one field with a default; no store changes. Ships in the next Blockout release; rollback by installing the previous release (older builds ignore the field).
