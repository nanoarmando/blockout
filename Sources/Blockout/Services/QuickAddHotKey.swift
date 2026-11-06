import AppKit
import Carbon.HIToolbox
import Observation

/// A global key combination: a virtual key code, Carbon modifier flags and the key as shown in Settings.
struct KeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    /// Ctrl+Option+Command+Shift+T, what a "Hyper" key sends with T.
    static let defaultNewTask = KeyShortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey), key: "T")

    /// The combination of a key press, or `nil` without Command, Option or Control.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        var modifiers = 0
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        if flags.contains(.command) { modifiers |= cmdKey }
        self.init(keyCode: UInt32(event.keyCode), modifiers: UInt32(modifiers), key: Self.keyName(event))
    }

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// macOS order and symbols, e.g. ⌃⌥⇧⌘T.
    var display: String {
        let symbols: [(Int, String)] = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
        return symbols.filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + key
    }

    private static func keyName(_ event: NSEvent) -> String {
        let names: [Int: String] = [
            kVK_Space: "Espacio", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        return names[Int(event.keyCode)] ?? (event.charactersIgnoringModifiers ?? "").uppercased()
    }
}

/// Owns the global shortcut of the quick-add bar through Carbon `RegisterEventHotKey`, which needs no
/// Accessibility permission and keeps the key press from reaching the frontmost app.
@MainActor
@Observable
final class QuickAddHotKey {
    /// The last combination macOS refused to register; Settings shows it as unavailable.
    private(set) var unavailable: KeyShortcut?
    @ObservationIgnored private var shortcut: KeyShortcut?
    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private let onPress: () -> Void

    init(shortcut: KeyShortcut?, onPress: @escaping () -> Void) {
        self.onPress = onPress
        installHandler()
        if register(shortcut) {
            self.shortcut = shortcut
        } else {
            unavailable = shortcut
        }
    }

    /// Replaces the shortcut; when the new one cannot be registered, the previous one is registered again
    /// and `false` is returned.
    func update(to newShortcut: KeyShortcut?) -> Bool {
        unregister()
        guard register(newShortcut) else {
            unavailable = newShortcut
            register(shortcut)
            return false
        }
        shortcut = newShortcut
        unavailable = nil
        return true
    }

    /// Releases the shortcut while Settings records a new one, so the press reaches the recorder.
    func pause() { unregister() }

    func resume() {
        guard hotKeyRef == nil else { return }
        register(shortcut)
    }

    @discardableResult
    private func register(_ shortcut: KeyShortcut?) -> Bool {
        guard let shortcut else { return true }
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x424C4B54), id: 1) // "BLKT"
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    private func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    /// One handler for the app's lifetime; the owner lives as long as the app, so the unretained pointer stays valid.
    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<QuickAddHotKey>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { owner.onPress() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
}
