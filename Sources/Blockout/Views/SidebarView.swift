import SwiftData
import SwiftUI

enum TaskFilter: Hashable {
    case all, today, unscheduled, scheduled, overdue, completed
    case project(UUID)
    case source(String)

    func matches(_ task: PlannerTask) -> Bool {
        switch self {
        case .all: true
        case .today: task.isForToday
        case .unscheduled: !task.isScheduled
        case .scheduled: task.isScheduled
        case .overdue: task.isOverdue
        case .completed: task.status == .done
        case .project(let id): task.project?.id == id
        case .source(let label): task.sourceLabel == label
        }
    }
}

struct SidebarView: View {
    @Binding var filter: TaskFilter
    let openTasks: [PlannerTask]
    let completedCount: Int
    let projects: [Project]

    @State private var showsAllProjects = false
    @State private var projectSheet: ProjectSheetTarget?

    private static let visibleProjectCount = 5
    private static let fixedFilters: [(TaskFilter, String)] = [
        (.all, "Todas"), (.today, "Hoy"), (.unscheduled, "Sin agendar"), (.scheduled, "Agendadas"), (.overdue, "Vencidas"), (.completed, "Completadas"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 2) {
                    ForEach(Self.fixedFilters, id: \.0) { item, title in
                        row(title, filter: item, count: count(item), countColor: countColor(item))
                    }
                }
                projectSection
                sourceSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .frame(width: 232)
        .background(Theme.sidebar)
        .sheet(item: $projectSheet) { ProjectSheet(target: $0) }
    }

    private var sortedProjects: [Project] {
        let counts: [UUID: Int] = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, count(.project($0.id))) })
        return projects.sorted { first, second in
            let firstCount = counts[first.id] ?? 0, secondCount = counts[second.id] ?? 0
            if firstCount != secondCount { return firstCount > secondCount }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
    }

    private var projectSection: some View {
        let sorted = sortedProjects
        let visible = showsAllProjects ? sorted : Array(sorted.prefix(Self.visibleProjectCount))
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Proyectos")
                Spacer()
                Button { projectSheet = .new } label: {
                    Image(systemName: "plus").font(.system(size: 12, weight: .medium)).frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.muted)
                .help("Nuevo proyecto")
                .padding(.trailing, 6)
            }
            ForEach(visible) { project in
                row(project.name, filter: .project(project.id), count: count(.project(project.id)), dot: ProjectPalette.fill(project.colorIndex))
                    .contextMenu {
                        Button("Editar…") { projectSheet = .edit(project) }
                    }
            }
            if sorted.count > Self.visibleProjectCount {
                Button(showsAllProjects ? "Ver menos" : "Ver más (\(sorted.count - Self.visibleProjectCount))") {
                    showsAllProjects.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.accentText)
                .padding(.horizontal, 10)
                .frame(height: 32)
            }
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        let sources = Set(openTasks.compactMap(\.sourceLabel)).sorted()
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                sectionTitle("Orígenes")
                ForEach(sources, id: \.self) { source in
                    row(source, filter: .source(source), count: count(.source(source)))
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11))
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
    }

    private func row(_ title: String, filter item: TaskFilter, count: Int, countColor: Color = Theme.muted, dot: Color? = nil) -> some View {
        Button {
            filter = item
        } label: {
            HStack(spacing: 10) {
                if let dot {
                    RoundedRectangle(cornerRadius: 3).fill(dot).frame(width: 10, height: 10)
                }
                Text(title).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(countColor)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(filter == item ? Theme.card : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func count(_ item: TaskFilter) -> Int {
        item == .completed ? completedCount : openTasks.count(where: item.matches)
    }

    private func countColor(_ item: TaskFilter) -> Color {
        switch item {
        case .unscheduled: Theme.accentText
        case .overdue: Theme.danger
        default: Theme.muted
        }
    }
}
