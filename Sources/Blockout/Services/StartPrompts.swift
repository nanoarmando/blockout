import Foundation
import Observation
import UserNotifications

/// "¿Estás trabajando en esto?" notifications at the start of today's blocks (D2). Pending requests are rebuilt
/// whenever block data changes (UI, MCP or reconciliation) and when the day changes. Without permission nothing is
/// scheduled and the prompt only lives in the menu bar menu.
@MainActor
@Observable
final class StartPrompts: NSObject, UNUserNotificationCenterDelegate {
    private enum Action {
        static let category = "BLOCK_START"
        static let start = "START"
        static let snooze = "SNOOZE"
        static let skip = "SKIP"
    }

    private static let requestPrefix = "block-start-"
    private nonisolated static let blockIDKey = "blockID"
    private static let snoozeMinutes = 5

    private let calendarService: CalendarService
    private let timeTracker: TimeTracker
    /// `UNUserNotificationCenter` aborts in a process without a bundle (e.g. `swift run`), so it is only used inside the app.
    @ObservationIgnored private let center: UNUserNotificationCenter? = Bundle.main.bundleIdentifier == nil ? nil : .current()
    @ObservationIgnored private var skipped: Set<UUID> = []
    @ObservationIgnored private var snoozedUntil: [UUID: Date] = [:]
    @ObservationIgnored private var scheduledDay = Date.distantPast

    private(set) var isAuthorized = false

    init(calendarService: CalendarService, timeTracker: TimeTracker) {
        self.calendarService = calendarService
        self.timeTracker = timeTracker
        super.init()
        guard let center else { return }
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Action.category,
                actions: [
                    UNNotificationAction(identifier: Action.start, title: "Sí, empezar"),
                    UNNotificationAction(identifier: Action.snooze, title: "En 5 min"),
                    UNNotificationAction(identifier: Action.skip, title: "Saltar"),
                ],
                intentIdentifiers: []
            )
        ])
        observeChanges()
        Task {
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            reschedule()
        }
    }

    /// Re-runs `reschedule` whenever block data changes or the minute ticker crosses into another day.
    private func observeChanges() {
        withObservationTracking {
            _ = calendarService.revision
            _ = timeTracker.today
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
        let requests: [UNNotificationRequest] = calendarService.blocks(in: today).compactMap { block in
            guard !skipped.contains(block.id), let task = block.task else { return nil }
            let fireDate = snoozedUntil[block.id].flatMap { $0 < block.end ? $0 : nil } ?? block.start
            guard fireDate > now else { return nil }
            let content = UNMutableNotificationContent()
            content.title = "¿Estás trabajando en esto?"
            content.body = "\(task.title) · \(PlannerFormat.timeRange(block.start, block.end))"
            content.categoryIdentifier = Action.category
            content.sound = .default
            content.userInfo = [Self.blockIDKey: block.id.uuidString]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSince(now), repeats: false)
            return UNNotificationRequest(identifier: Self.requestPrefix + block.id.uuidString, content: content, trigger: trigger)
        }
        Task {
            let stale = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.requestPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for request in requests {
                try? await center.add(request)
            }
        }
    }

    private func block(withID id: UUID) -> Block? {
        calendarService.blocks(in: Calendar.planner.dayInterval(containing: .now)).first { $0.id == id }
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
        default:
            break
        }
    }

    /// A prompt is not shown when the timer already runs for the block's task.
    private func shouldPresent(blockID: UUID) -> Bool {
        guard let task = block(withID: blockID)?.task else { return false }
        return !timeTracker.isRunning(task)
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        guard let blockID = Self.blockID(of: notification) else { return [.banner, .sound] }
        return await shouldPresent(blockID: blockID) ? [.banner, .sound] : []
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
