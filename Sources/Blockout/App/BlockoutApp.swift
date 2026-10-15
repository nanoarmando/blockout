import AppKit
import SwiftData
import SwiftUI

@main
struct BlockoutApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let container: ModelContainer
    @State private var settingsStore: SettingsStore
    @State private var calendarService: CalendarService
    @State private var dragState = DragState()
    @State private var mcpServer: MCPServer
    @State private var timeTracker: TimeTracker
    @State private var startPrompts: StartPrompts
    @State private var updates: UpdateCoordinator

    init() {
        do {
            container = try BlockoutStore.makeContainer()
        } catch {
            fatalError("Could not open the Blockout store: \(error)")
        }
        let settingsStore = SettingsStore()
        _settingsStore = State(initialValue: settingsStore)
        let calendarService = CalendarService(context: container.mainContext, settingsStore: settingsStore)
        _calendarService = State(initialValue: calendarService)
        let mcpServer = MCPServer(tools: MCPTools(context: container.mainContext, calendarService: calendarService, settingsStore: settingsStore))
        mcpServer.configure(enabled: settingsStore.settings.mcpEnabled, port: settingsStore.settings.mcpPort)
        _mcpServer = State(initialValue: mcpServer)
        let timeTracker = TimeTracker(context: container.mainContext, calendarService: calendarService)
        _timeTracker = State(initialValue: timeTracker)
        _startPrompts = State(initialValue: StartPrompts(calendarService: calendarService, timeTracker: timeTracker))
        let updates = UpdateCoordinator()
        updates.isAppBusy = { timeTracker.running != nil }
        updates.start()
        _updates = State(initialValue: updates)
    }

    var body: some Scene {
        Window("Blockout", id: "main") {
            MainView()
                .environment(settingsStore)
                .environment(calendarService)
                .environment(timeTracker)
                .environment(dragState)
                .task { await calendarService.requestAccessIfNeeded() }
        }
        .modelContainer(container)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuItems().environment(updates)
            }
        }

        Window("Acerca de Blockout", id: AboutView.windowID) {
            AboutView()
                .environment(updates)
                .environment(timeTracker)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarMenu()
                .environment(calendarService)
                .environment(timeTracker)
                .environment(updates)
        } label: {
            MenuBarLabel { openWindow in appDelegate.openMainWindow = { openWindow(id: "main") } }
                .environment(timeTracker)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(settingsStore)
                .environment(mcpServer)
                .environment(calendarService)
                .modelContainer(container)
        }
    }
}

/// Keeps Blockout running when the main window closes (the timer and the MCP server need it) and reopens the
/// window from the Dock.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor var openMainWindow: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { openMainWindow?() }
        return true
    }
}
