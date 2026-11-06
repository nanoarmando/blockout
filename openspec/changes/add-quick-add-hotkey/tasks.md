## 1. Settings model

- [x] 1.1 Add the shortcut (key code and modifiers, null for disabled) to the settings struct with the Ctrl+Option+Command+Shift+T default in the decoder (Shortcut setting; Shortcut stored as key code plus modifier flags)

## 2. Hotkey and bar

- [x] 2.1 Add the hotkey owner using Carbon `RegisterEventHotKey`: register at startup, re-register on change, keep the previous shortcut and report failure (Global shortcut opens the quick-add bar; Shortcut setting)
- [x] 2.2 Add the floating panel with the input, the project hint, Enter to create through the existing parser and creation helper, Esc and focus loss to dismiss, errors under the input, and focus returned to the previous app (Create a task from the bar; Dismiss the bar)
- [x] 2.3 Create the hotkey owner and the panel at app startup with the shared model context (Global shortcut opens the quick-add bar)

## 3. Settings interface

- [x] 3.1 Add the "Atajos" section with the "Nueva tarea" recorder, modifier validation, clear button, unavailable message, and the global hotkey paused while recording (Shortcut setting)

## 4. Docs and verification

- [x] 4.1 Update `README.md` (quick-add bar, settings) and `AGENTS.md` (structure, contracts)
- [ ] 4.2 Verify every scenario with a debug build on a scratch store (`BLOCKOUT_STORE_DIR`), including the window closed, another app active, and a combination that fails to register
