import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The filter-and-create input and the "Sin agendar" / "Agendadas" groups. Dropping a block here unschedules it.
struct TaskListView: View {
    let tasks: [PlannerTask]
    /// Done tasks matching the sidebar filter; shown in "Completadas" when toggled on or with that filter.
    let completedTasks: [PlannerTask]
    let onlyCompleted: Bool
    let projects: [Project]
    let openTask: (PlannerTask) -> Void

    @AppStorage("showsCompletedTasks") private var showsCompleted = false

    @Environment(\.modelContext) private var modelContext
    @Environment(CalendarService.self) private var calendarService
    @Environment(DragState.self) private var dragState
    @State private var query = ""
    /// The quick input takes the initial focus; otherwise macOS focuses the first field ("Nuevo proyecto").
    @FocusState private var isInputFocused: Bool
    @State private var isBlockOver = false
    @State private var taskToDelete: PlannerTask?

    private var needle: String { query.trimmingCharacters(in: .whitespaces) }

    private var matchingTasks: [PlannerTask] { tasks.filter(matchesQuery) }

    private func matchesQuery(_ task: PlannerTask) -> Bool {
        guard !needle.isEmpty else { return true }
        return [task.title, task.project?.name, task.sourceLabel, task.externalRefLabel]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(needle) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            input
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !onlyCompleted {
                        let unscheduled = tasks.filter { !$0.isScheduled }
                        let scheduled = tasks.filter(\.isScheduled)
                        group(
                            "Sin agendar",
                            all: unscheduled,
                            hint: "Arrastra al calendario",
                            sort: { ($0.urgency, $0.createdAt) > ($1.urgency, $1.createdAt) }
                        )
                        group(
                            "Agendadas",
                            all: scheduled,
                            hint: Self.taskCount(scheduled.count),
                            sort: { ($0.nextBlock?.start ?? .distantFuture) < ($1.nextBlock?.start ?? .distantFuture) }
                        )
                    }
                    if onlyCompleted || showsCompleted {
                        group("Completadas", all: completedTasks, hint: Self.taskCount(completedTasks.count), sort: { $0.createdAt > $1.createdAt })
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 380)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .overlay {
            if isBlockOver {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.plainText], delegate: UnscheduleDropDelegate(dragState: dragState, isTargeted: $isBlockOver) { blockID in
            guard let block = try? modelContext.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == blockID })).first
            else { return false }
            return calendarService.deleteBlock(block)
        })
        .confirmationDialog(
            "¿Eliminar «\(taskToDelete?.title ?? "")»?",
            isPresented: Binding(get: { taskToDelete != nil }, set: { if !$0 { taskToDelete = nil } })
        ) {
            Button("Eliminar", role: .destructive) {
                if let task = taskToDelete { calendarService.deleteTask(task) }
                taskToDelete = nil
            }
            Button("Cancelar", role: .cancel) { taskToDelete = nil }
        } message: {
            Text(deleteMessage)
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Buscar o crear tarea").font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Button { showsCompleted.toggle() } label: {
                    Image(systemName: showsCompleted ? "checkmark.circle.fill" : "checkmark.circle").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(showsCompleted ? Theme.accentText : Theme.muted)
                .help(showsCompleted ? "Ocultar completadas" : "Mostrar completadas")
            }
            TextField("Filtra o escribe y presiona Enter para crear", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.control))
                .focused($isInputFocused)
                .onAppear { isInputFocused = true }
                .onSubmit(create)
            if needle.isEmpty {
                Text("Al crear: nombra el proyecto en el texto y termina con 2h para estimar y !, !! o !!! para urgencia")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            } else {
                let count = matchingTasks.count
                let project = QuickEntryParser.detectProject(in: needle, projectNames: projects.map(\.name))
                HStack(alignment: .top, spacing: 8) {
                    Text(count == 1 ? "1 coincidencia" : "\(count) coincidencias").foregroundStyle(Theme.muted)
                    Spacer()
                    Text("↵ Crear «\(needle)»" + (project.map { " en \($0)" } ?? ""))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 12))
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, all: [PlannerTask], hint: String, sort: (PlannerTask, PlannerTask) -> Bool) -> some View {
        let shown = all.filter(matchesQuery).sorted(by: sort)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(needle.isEmpty ? hint : "\(shown.count) de \(all.count)").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
            ForEach(shown) { task in
                TaskRow(task: task)
                    .onTapGesture { openTask(task) }
                    .contextMenu { contextMenu(for: task) }
                    .onDrag {
                        dragState.payload = .task(task.id)
                        return NSItemProvider(object: task.id.uuidString as NSString)
                    }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for task: PlannerTask) -> some View {
        Button("Abrir") { openTask(task) }
        Picker("Urgencia", selection: Binding(get: { task.urgency }, set: { task.urgency = $0 })) {
            Text("Ninguna").tag(0)
            ForEach(1...3, id: \.self) { Text(String(repeating: "!", count: $0)).tag($0) }
        }
        .pickerStyle(.menu)
        Divider()
        Button("Eliminar…", role: .destructive) { taskToDelete = task }
    }

    private var deleteMessage: String {
        let count = taskToDelete?.blocks.count ?? 0
        let blocks = count == 0 ? "No tiene bloques." : count == 1 ? "Se borrará 1 bloque y su evento de calendario." : "Se borrarán \(count) bloques y sus eventos de calendario."
        return "\(blocks) Esta acción no se puede deshacer."
    }

    private func create() {
        guard !needle.isEmpty else { return }
        let entry = QuickEntryParser.parse(needle, projectNames: projects.map(\.name))
        do {
            try modelContext.createTask(from: entry, projects: projects)
            query = ""
        } catch {
            calendarService.otherErrorMessage = error.localizedDescription
        }
    }
}

private struct UnscheduleDropDelegate: DropDelegate {
    let dragState: DragState
    @Binding var isTargeted: Bool
    let unschedule: (UUID) -> Bool

    private var blockID: UUID? {
        if case .block(let id) = dragState.payload { return id }
        return nil
    }

    func validateDrop(info: DropInfo) -> Bool { blockID != nil }
    func dropEntered(info: DropInfo) { isTargeted = true }
    func dropExited(info: DropInfo) { isTargeted = false }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            isTargeted = false
            dragState.finish()
        }
        guard let blockID else { return false }
        return unschedule(blockID)
    }
}

private struct TaskRow: View {
    let task: PlannerTask

    @Environment(CalendarService.self) private var calendarService

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CompletionButton(isDone: task.status == .done) {
                // Unchecking a completed task reopens it, like the task detail
                if task.status == .done { task.status = .todo } else { calendarService.complete(task) }
            }
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title).font(.system(size: 14)).lineSpacing(2)
                    .foregroundStyle(task.status == .done ? Theme.muted : Theme.ink)
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var meta: some View {
        let hasMeta = task.project != nil || task.urgency > 0 || task.estimateMinutes != nil
            || task.originLabel != nil || task.nextBlock != nil || task.dueDate != nil
        if hasMeta {
            FlowLayout {
                if let project = task.project { ProjectChip(project: project) }
                if task.urgency > 0 { UrgencyBars(level: task.urgency) }
                if let estimate = task.estimateMinutes {
                    Text(PlannerFormat.hours(minutes: estimate)).font(.system(size: 12, design: .monospaced))
                }
                if let origin = task.originLabel {
                    if let url = task.externalURL {
                        Link(origin, destination: url).foregroundStyle(Theme.accentText).pointerStyle(.link)
                    } else {
                        Text(origin)
                    }
                }
                if let next = task.nextBlock {
                    Text(PlannerFormat.nextBlock(next.start)).foregroundStyle(Theme.ink)
                }
                if let due = task.dueDate {
                    Text(PlannerFormat.due(due, overdue: task.isOverdue))
                        .fontWeight(task.isOverdue ? .medium : .regular)
                        .foregroundStyle(task.isOverdue ? Theme.danger : Theme.muted)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
        }
    }
}

extension TaskListView {
    static func taskCount(_ count: Int) -> String { count == 1 ? "1 tarea" : "\(count) tareas" }
}
