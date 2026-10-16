import AppKit
import SwiftUI

/// The menu bar item: the template icon, plus the elapsed time and a short task name while a timer runs.
struct MenuBarLabel: View {
    @Environment(TimeTracker.self) private var timeTracker
    @Environment(\.openWindow) private var openWindow
    let onAppear: (OpenWindowAction) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image)
            if let entry = timeTracker.running, let task = entry.task {
                Text("\(PlannerFormat.clock(minutes: entry.minutes(now: timeTracker.now))) \(PlannerFormat.shortTitle(task.title))")
                    .monospacedDigit()
            }
        }
        .onAppear { onAppear(openWindow) }
    }
}

@MainActor
enum MenuBarIcon {
    /// `Resources/MenuBarIcon.svg` bundled by `Scripts/build.sh`; an SF Symbol when running outside the app bundle.
    static let image: NSImage = {
        let image = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg").flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
            ?? NSImage()
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        image.accessibilityDescription = "Blockout"
        return image
    }()
}

/// The native menu (`MenuBarExtra` with `.menu` style): the current or next block with the timer actions, the rest of
/// today and the app shortcuts. No task creation here.
struct MenuBarMenu: View {
    @Environment(CalendarService.self) private var calendarService
    @Environment(TimeTracker.self) private var timeTracker
    @Environment(StartPrompts.self) private var startPrompts
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private struct LaterItem: Identifiable {
        let id: String
        let title: String
        let time: String
        let start: Date
        let isEvent: Bool
    }

    var body: some View {
        let now = timeTracker.now
        let _ = calendarService.revision
        let today = Calendar.planner.dayInterval(containing: now)
        let blocks = calendarService.blocks(in: today).sorted { $0.start < $1.start }
        let current = blocks.first { $0.start <= now && $0.end > now }
        let task = timeTracker.running?.task ?? timeTracker.idle?.task ?? (current ?? blocks.first { $0.start > now })?.task
        let block = task.flatMap { task in blocks.first { $0.task?.id == task.id && $0.end > now } }

        Section(heading(block: block, now: now)) {
            if let task {
                Text(title(task, now: now))
                if let details = details(task, block: block) { Text(details) }
                actions(task, block: block, now: now)
            }
        }
        if let summary = timeTracker.blockExtension, summary.blockID == block?.id {
            Text("Extendida \(summary.minutes) min · se corrieron \(summary.previousStarts.count) \(summary.previousStarts.count == 1 ? "bloque" : "bloques")")
            Text("Las reuniones no se mueven; lo que choca salta después.")
        }
        Divider()
        Section("Después") {
            ForEach(laterItems(blocks: blocks, excluding: block, today: today, now: now)) { item in
                Button(action: openMain) {
                    Label("\(PlannerFormat.truncated(item.title))   \(item.time)", systemImage: item.isEvent ? "circle" : "circle.fill")
                }
            }
        }
        Divider()
        if startPrompts.isAvailable, !startPrompts.isAuthorized {
            Text("Notificaciones desactivadas")
            Button("Abrir Ajustes") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
        }
        Button("Abrir Blockout", action: openMain).keyboardShortcut("o")
        AboutMenuItems()
        Button("Ajustes…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        .task { await startPrompts.refreshAuthorization() }
    }

    private func heading(block: Block?, now: Date) -> String {
        if timeTracker.running != nil { return "Trabajando ahora" }
        switch timeTracker.idle?.reason {
        case .paused: return "En pausa"
        case .stopped: return "Detenido"
        case .completed: return "Terminado"
        case nil: break
        }
        guard let block else { return "No quedan bloques hoy" }
        return block.start <= now ? "Empieza ahora" : "A las \(PlannerFormat.time(block.start))"
    }

    /// The task title, with the elapsed time while it runs or is paused.
    private func title(_ task: PlannerTask, now: Date) -> String {
        if let entry = timeTracker.running ?? (timeTracker.idle?.reason == .paused ? timeTracker.idle?.entry : nil) {
            return "\(task.title)   \(PlannerFormat.clock(minutes: entry.minutes(now: now)))"
        }
        return task.title
    }

    /// "11:00 – 12:00 · Northwind · Odoo #8896"
    private func details(_ task: PlannerTask, block: Block?) -> String? {
        let parts = [block.map { PlannerFormat.timeRange($0.start, $0.end) }, task.project?.name, task.externalRefLabel].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func actions(_ task: PlannerTask, block: Block?, now: Date) -> some View {
        if timeTracker.isRunning(task) {
            Button("Completar") { timeTracker.complete() }
            if let block, block.start <= now {
                Button("+\(TimeTracker.extensionMinutes) min") { timeTracker.extend(block) }
            }
            Button("Pausar") { timeTracker.pause() }
            Button("Detener") { timeTracker.stop() }
        } else if let idle = timeTracker.idle, idle.task.id == task.id {
            let recorded = PlannerFormat.clock(minutes: idle.entry.minutes(now: now))
            switch idle.reason {
            case .paused:
                Button("Completar") { timeTracker.complete() }
                Button("Reanudar") { timeTracker.resume() }
                Button("Detener") { timeTracker.stop() }
            case .stopped:
                Text("Detenido · \(recorded) guardadas en la tarea")
                Button("Retomar") { timeTracker.resume() }
            case .completed:
                Text("Completada · \(recorded) guardadas en la tarea")
            }
        } else {
            Button("Empezar") { timeTracker.start(task) }
        }
    }

    /// The rest of today's blocks and timed events in time order, marking shifted blocks "antes → ahora" and
    /// listing blocks the extension left without a place.
    private func laterItems(blocks: [Block], excluding focus: Block?, today: DateInterval, now: Date) -> [LaterItem] {
        let previousStarts = timeTracker.blockExtension?.previousStarts ?? [:]
        let blockItems = blocks.filter { $0.end > now && $0.id != focus?.id }.map { block in
            let time = previousStarts[block.id].map { "\(PlannerFormat.time($0)) → \(PlannerFormat.time(block.start))" } ?? PlannerFormat.time(block.start)
            return LaterItem(id: block.id.uuidString, title: block.task?.title ?? "", time: time, start: block.start, isEvent: false)
        }
        let eventItems = calendarService.events(in: today).filter { !$0.isAllDay && $0.end > now }.map { event in
            LaterItem(id: event.id, title: event.title, time: PlannerFormat.time(event.start), start: event.start, isEvent: true)
        }
        let unplaced = (timeTracker.blockExtension?.unplaced ?? []).enumerated().map { index, item in
            LaterItem(id: "unplaced-\(index)", title: item.title, time: "Sin lugar", start: item.start, isEvent: false)
        }
        return (blockItems + eventItems + unplaced).sorted { $0.start < $1.start }
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate()
    }
}
