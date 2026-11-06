import AppKit
import SwiftData
import SwiftUI

/// The floating quick-add bar opened by the global shortcut. It activates the app to take typing and, after
/// creating or dismissing, hides and returns focus to the app that was active before.
@MainActor
final class QuickAddController: NSObject, NSWindowDelegate {
    private let context: ModelContext
    private let state = QuickAddState()
    private var previousApp: NSRunningApplication?
    private lazy var panel: QuickAddWindow = {
        let panel = QuickAddWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 96), styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.dismiss() }
        return panel
    }()

    init(context: ModelContext) {
        self.context = context
    }

    func toggle() {
        panel.isVisible ? dismiss() : show()
    }

    private func show() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : frontmost
        // A fresh hosting view each time so the input gets focus on appear
        let hostingView = NSHostingView(rootView: QuickAddBar(state: state, submit: { [weak self] in self?.submit() }).modelContext(context))
        panel.contentView = hostingView
        panel.setContentSize(hostingView.fittingSize)
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - visible.height * 0.2 - size.height))
        }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closes without creating and clears the text, so the bar opens empty next time.
    private func dismiss() {
        guard panel.isVisible else { return }
        state.text = ""
        state.error = nil
        panel.orderOut(nil)
        previousApp?.activate()
        previousApp = nil
    }

    private func submit() {
        let text = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try context.createTask(parsing: text)
            dismiss()
        } catch {
            state.error = error.localizedDescription
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }
}

@MainActor
@Observable
private final class QuickAddState {
    var text = ""
    var error: String?
}

/// Borderless panels refuse key status by default; the bar needs it for typing. Esc arrives as `cancelOperation`.
private final class QuickAddWindow: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

private struct QuickAddBar: View {
    @Bindable var state: QuickAddState
    let submit: () -> Void
    @Query private var projects: [Project]
    @FocusState private var isFocused: Bool

    var body: some View {
        let needle = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 8) {
            TextField("Nueva tarea: nombra el proyecto, 2h para estimar y !, !! o !!! para urgencia", text: $state.text)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($isFocused)
                .onAppear { isFocused = true }
                .onSubmit(submit)
                .onChange(of: state.text) { state.error = nil }
            if let error = state.error {
                Text(verbatim: error)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
            } else if !needle.isEmpty {
                CreateTaskHint(text: needle, projectNames: projects.map(\.name))
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 640, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }
}
