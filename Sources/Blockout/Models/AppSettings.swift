import Foundation
import Observation

enum DefaultBlockLength: String, Codable, CaseIterable, Identifiable {
    case sixtyMinutes, thirtyMinutes, fromEstimate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sixtyMinutes: "60 min"
        case .thirtyMinutes: "30 min"
        case .fromEstimate: "Según la estimación"
        }
    }

    /// Fixed length; "según la estimación" falls back to 60 minutes for tasks without estimate.
    var minutes: Int { self == .thirtyMinutes ? 30 : 60 }
}

struct AppSettings: Codable, Equatable {
    var destinationCalendarID: String?
    var blocksShowAsBusy = true
    /// `nil` until the user picks; then every available calendar is read.
    var readCalendarIDs: Set<String>?
    var workdayStartMinutes = 8 * 60
    var workdayEndMinutes = 18 * 60
    var defaultBlockLength = DefaultBlockLength.sixtyMinutes
    var mcpEnabled = true
    var mcpPort = MCPServer.defaultPort

    /// Length of a new block: the setting decides; the estimate is only used with "según la estimación".
    func blockMinutes(for task: PlannerTask) -> Int {
        defaultBlockLength == .fromEstimate ? task.estimateMinutes ?? defaultBlockLength.minutes : defaultBlockLength.minutes
    }

    /// Working interval of a day, or `nil` on weekends.
    func workday(containing day: Date) -> DateInterval? {
        let calendar = Calendar.planner
        guard !calendar.isDateInWeekend(day) else { return nil }
        let start = calendar.startOfDay(for: day)
        return DateInterval(
            start: start.addingTimeInterval(TimeInterval(workdayStartMinutes * 60)),
            end: start.addingTimeInterval(TimeInterval(workdayEndMinutes * 60))
        )
    }
}

extension AppSettings {
    /// Missing keys keep their defaults, so settings saved by an older version survive new fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        destinationCalendarID = try container.decodeIfPresent(String.self, forKey: .destinationCalendarID)
        blocksShowAsBusy = try container.decodeIfPresent(Bool.self, forKey: .blocksShowAsBusy) ?? blocksShowAsBusy
        readCalendarIDs = try container.decodeIfPresent(Set<String>.self, forKey: .readCalendarIDs)
        workdayStartMinutes = try container.decodeIfPresent(Int.self, forKey: .workdayStartMinutes) ?? workdayStartMinutes
        workdayEndMinutes = try container.decodeIfPresent(Int.self, forKey: .workdayEndMinutes) ?? workdayEndMinutes
        defaultBlockLength = try container.decodeIfPresent(DefaultBlockLength.self, forKey: .defaultBlockLength) ?? defaultBlockLength
        mcpEnabled = try container.decodeIfPresent(Bool.self, forKey: .mcpEnabled) ?? mcpEnabled
        mcpPort = try container.decodeIfPresent(Int.self, forKey: .mcpPort) ?? mcpPort
    }
}

@MainActor
@Observable
final class SettingsStore {
    private static let key = "settings"

    var settings: AppSettings {
        didSet { save() }
    }

    init() {
        settings = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? AppSettings()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
