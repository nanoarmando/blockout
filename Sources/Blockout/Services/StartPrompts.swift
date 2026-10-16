import AppKit
import Observation
import os
import UserNotifications

/// Block notifications for today: "¿Estás trabajando en esto?" at the start of each block (D2) and "¿Terminaste esta
/// tarea?" at the end of a block whose task has the timer running. Pending requests are rebuilt whenever block data
/// or the running timer changes (UI, MCP or reconciliation) and when the day changes. Without permission nothing is
/// scheduled and the prompt only lives in the menu bar menu.
@MainActor
@Observable
final class StartPrompts: NSObject, UNUserNotificationCenterDelegate {
    private enum Action {
        static let startCategory = "BLOCK_START"
        static let endCategory = "BLOCK_END"
        static let start = "START"
        static let snooze = "SNOOZE"
        static let skip = "SKIP"
        static let complete = "COMPLETE"
        static let extend = "EXTEND"
    }

    private static let startPrefix = "block-start-"
    private static let endPrefix = "block-end-"
    private nonisolated static let blockIDKey = "blockID"
    private static let snoozeMinutes = 5
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blockout", category: "notifications")

    private let calendarService: CalendarService
    private let timeTracker: TimeTracker
    /// `UNUserNotificationCenter` aborts in a process without a bundle (e.g. `swift run`), so it is only used inside the app.
    @ObservationIgnored private let center: UNUserNotificationCenter? = Bundle.main.bundleIdentifier == nil ? nil : .current()
    @ObservationIgnored private var skipped: Set<UUID> = []
    @ObservationIgnored private var snoozedUntil: [UUID: Date] = [:]
    @ObservationIgnored private var scheduledDay = Date.distantPast
    /// The last remove/add run; each new run waits for it so concurrent runs do not drop each other's requests.
    @ObservationIgnored private var rebuild: Task<Void, Never>?

    private(set) var isAuthorized = false

    /// `false` when notifications cannot be used at all (no app bundle), so the menu does not ask for permission.
    var isAvailable: Bool { center != nil }

    init(calendarService: CalendarService, timeTracker: TimeTracker) {
        self.calendarService = calendarService
        self.timeTracker = timeTracker
        super.init()
        guard let center else { return }
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Action.startCategory,
                actions: [
                    UNNotificationAction(identifier: Action.start, title: "Sí, empezar"),
                    UNNotificationAction(identifier: Action.snooze, title: "En 5 min"),
                    UNNotificationAction(identifier: Action.skip, title: "Saltar"),
                ],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Action.endCategory,
                actions: [
                    UNNotificationAction(identifier: Action.complete, title: "Terminada"),
                    UNNotificationAction(identifier: Action.extend, title: "+\(TimeTracker.extensionMinutes) min"),
                ],
                intentIdentifiers: []
            ),
        ])
        observeChanges()
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = Task { await self?.refreshAuthorization() }
            }
        }
        Task {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                Self.logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
            await refreshAuthorization()
        }
    }

    /// Re-reads the notification settings, so permission granted later in System Settings applies without a relaunch.
    func refreshAuthorization() async {
        guard let center else { return }
        let status = await center.notificationSettings().authorizationStatus
        let authorized = status == .authorized || status == .provisional
        guard authorized != isAuthorized else { return }
        isAuthorized = authorized
        reschedule()
    }

    /// Re-runs `reschedule` whenever block data or the running timer changes, or the minute ticker crosses into another day.
    private func observeChanges() {
        withObservationTracking {
            _ = calendarService.revision
            _ = timeTracker.today
            _ = timeTracker.running
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.reschedule()
                self?.observeChanges()
            }
        }
    }

    private func reschedule() {
        guard let center, isAuthorized else { return }
        let now = Date.now
        let today = Calendar.planner.dayInterval(containing: now)
        if today.start != scheduledDay {
            scheduledDay = today.start
            skipped = []
            snoozedUntil = [:]
        }
        var requests: [UNNotificationRequest] = []
        for block in calendarService.blocks(in: today) {
            guard let task = block.task else { continue }
            let range = "\(task.blockTitle) · \(PlannerFormat.timeRange(block.start, block.end))"
            if !skipped.contains(block.id) {
                let fireDate = snoozedUntil[block.id].flatMap { $0 < block.end ? $0 : nil } ?? block.start
                if fireDate > now {
                    requests.append(request(Self.startPrefix, block: block, title: "¿Estás trabajando en esto?", body: range, category: Action.startCategory, at: fireDate))
                }
            }
            if timeTracker.isRunning(task), block.end > now {
                requests.append(request(Self.endPrefix, block: block, title: "¿Terminaste esta tarea?", body: range, category: Action.endCategory, at: block.end))
            }
        }
        let previous = rebuild
        rebuild = Task {
            await previous?.value
            let stale = await center.pendingNotificationRequests().map(\.identifier).filter {
                $0.hasPrefix(Self.startPrefix) || $0.hasPrefix(Self.endPrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for request in requests {
                do {
                    try await center.add(request)
                } catch {
                    Self.logger.error("Could not schedule \(request.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func request(_ prefix: String, block: Block, title: String, body: String, category: String, at date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.sound = .default
        content.userInfo = [Self.blockIDKey: block.id.uuidString]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: prefix + block.id.uuidString, content: content, trigger: trigger)
    }

    private func block(withID id: UUID) -> Block? {
        calendarService.blocks(in: Calendar.planner.dayInterval(containing: .now)).first { $0.id == id }
    }

    private func isTimerRunning(for block: Block) -> Bool {
        block.task.map(timeTracker.isRunning) ?? false
    }

    private func handle(action: String, blockID: UUID) {
        guard let block = block(withID: blockID) else { return }
        switch action {
        case Action.start:
            if let task = block.task { timeTracker.start(task) }
        case Action.snooze:
            let fireDate = Date.now.addingTimeInterval(TimeInterval(Self.snoozeMinutes * 60))
            guard fireDate < block.end else { return }
            snoozedUntil[blockID] = fireDate
            reschedule()
        case Action.skip:
            skipped.insert(blockID)
            reschedule()
        case Action.complete:
            if isTimerRunning(for: block) { timeTracker.complete() }
        case Action.extend:
            timeTracker.extend(block)
        default:
            break
        }
    }

    /// A start prompt is not shown when the timer already runs for the block's task; an end prompt only while it does.
    private func shouldPresent(blockID: UUID, category: String) -> Bool {
        guard let block = block(withID: blockID), block.task != nil else { return false }
        return isTimerRunning(for: block) == (category == Action.endCategory)
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        guard let blockID = Self.blockID(of: notification) else { return [.banner, .sound] }
        let category = notification.request.content.categoryIdentifier
        return await shouldPresent(blockID: blockID, category: category) ? [.banner, .sound] : []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let blockID = Self.blockID(of: response.notification) else { return }
        let action = response.actionIdentifier
        await handle(action: action, blockID: blockID)
    }

    private nonisolated static func blockID(of notification: UNNotification) -> UUID? {
        (notification.request.content.userInfo[blockIDKey] as? String).flatMap(UUID.init(uuidString:))
    }
}
