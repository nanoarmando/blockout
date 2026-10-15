import SwiftData
import SwiftUI

/// Task detail. Edits go straight to the model, so they are saved without an explicit action.
struct TaskDetailView: View {
    @Bindable var task: PlannerTask
    let projects: [Project]

    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarService.self) private var calendarService
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TimeTracker.self) private var timeTracker
    @State private var timeEditError: String?
    /// Block title last written to the calendar events; title and project edits sync after a pause and on close.
    @State private var syncedBlockTitle: String?

    private var sortedBlocks: [Block] { task.confirmedBlocks.sorted { $0.start < $1.start } }
    private var remainingMinutes: Int { max(0, (task.estimateMinutes ?? 0) - task.scheduledMinutes) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 12) {
                        CompletionButton(isDone: task.status == .done, size: 24) {
                            if task.status == .done { task.status = .todo } else { calendarService.complete(task) }
                        }
                        .padding(.top, 3)
                        TextField("Título", text: $task.title, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 22, weight: .semibold))
                    }
                    fields
                    blocksSection
                    timeSection
                    notes
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
            }
        }
        .frame(width: 560, height: 720)
        .background(Theme.card)
        // macOS focuses the title and selects it when the sheet opens; start with nothing focused instead
        .onAppear {
            syncedBlockTitle = task.blockTitle
            DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .task(id: task.blockTitle) {
            guard syncedBlockTitle != nil, task.blockTitle != syncedBlockTitle else { return }
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { syncEventTitles() }
        }
        .onDisappear(perform: syncEventTitles)
    }

    private var header: some View {
        HStack(spacing: 10) {
            projectMenu
            if let label = task.externalRefLabel, let url = task.externalURL {
                Link(label, destination: url).font(.system(size: 12)).foregroundStyle(Theme.accentText).pointerStyle(.link)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .medium)).frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.muted)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Cerrar")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Theme.lineSoft.frame(height: 1) }
    }

    private func syncEventTitles() {
        guard let synced = syncedBlockTitle, task.blockTitle != synced else { return }
        syncedBlockTitle = task.blockTitle
        calendarService.syncEventTitles(of: [task])
    }

    /// The project chip itself opens the project menu.
    private var projectMenu: some View {
        Menu {
            Picker("Proyecto", selection: $task.project) {
                Text("Sin proyecto").tag(Project?.none)
                ForEach(projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { project in
                    Text(project.name).tag(Optional(project))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                if let project = task.project {
                    ProjectChip(project: project)
                } else {
                    Text("Sin proyecto")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                        .overlay(Capsule().strokeBorder(Theme.control, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.muted)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .pointerStyle(.link)
        .help("Cambiar proyecto")
    }

    private var fields: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
            GridRow {
                label("Estado")
                HStack(spacing: 6) {
                    ForEach(TaskStatus.allCases.filter { $0 != .done }) { status in
                        Button(status.label) { task.status = status }
                            .buttonStyle(ToggleButtonStyle(isSelected: task.status == status))
                    }
                }
            }
            GridRow {
                label("Urgencia")
                HStack(spacing: 6) {
                    ForEach(0...3, id: \.self) { level in
                        Button(level == 0 ? "—" : String(repeating: "!", count: level)) { task.urgency = level }
                            .font(.system(size: 14, design: level == 0 ? .default : .monospaced))
                            .frame(minWidth: 44)
                            .buttonStyle(ToggleButtonStyle(isSelected: task.urgency == level, selectedFill: level == 3 ? Theme.urgentHigh : Theme.strong, selectedText: level == 3 ? .white : Theme.onStrong))
                    }
                }
            }
            GridRow {
                label("Estimación")
                HStack(spacing: 6) {
                    TextField("—", value: estimateHours, format: .number.precision(.fractionLength(0...2)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("h").foregroundStyle(Theme.muted)
                }
            }
            GridRow {
                label("Vence")
                HStack(spacing: 8) {
                    if let due = task.dueDate {
                        DatePicker("Vence", selection: Binding(get: { due }, set: { task.dueDate = $0 }), displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, .planner)
                        Button("Quitar") { task.dueDate = nil }.buttonStyle(.link)
                    } else {
                        Button("Agregar fecha") { task.dueDate = Calendar.planner.startOfDay(for: .now) }.buttonStyle(.link)
                    }
                }
            }
            if let source = task.sourceLabel {
                GridRow {
                    label("Origen")
                    Text(source).font(.system(size: 13)).foregroundStyle(Theme.secondary)
                }
            }
        }
        .font(.system(size: 14))
    }

    private func label(_ title: String) -> some View {
        Text(title).foregroundStyle(Theme.muted).frame(width: 120, alignment: .leading)
    }

    private var estimateHours: Binding<Double?> {
        Binding(
            get: { task.estimateMinutes.map { Double($0) / 60 } },
            set: { hours in task.estimateMinutes = hours.flatMap { $0 > 0 ? Int(($0 * 60).rounded()) : nil } }
        )
    }

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bloques").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(scheduledSummary).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            ForEach(sortedBlocks) { block in
                blockRow(block)
            }
            if remainingMinutes > 0 {
                Button("+ Agendar las \(PlannerFormat.hours(minutes: remainingMinutes)) restantes", action: scheduleRemaining)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
        }
    }

    private var scheduledSummary: String {
        let scheduled = PlannerFormat.hours(minutes: task.scheduledMinutes)
        guard let estimate = task.estimateMinutes else { return "\(scheduled) agendada" }
        return "\(scheduled) de \(PlannerFormat.hours(minutes: estimate)) agendada"
    }

    private func blockRow(_ block: Block) -> some View {
        let colorIndex = task.project?.colorIndex
        return HStack(spacing: 12) {
            Image(systemName: "calendar")
            VStack(alignment: .leading, spacing: 2) {
                Text("\(PlannerFormat.dayMonth(block.start)) · \(PlannerFormat.timeRange(block.start, block.end))").fontWeight(.medium)
                if let summary = calendarService.eventSummary(for: block) {
                    Text(summary).font(.system(size: 12))
                }
            }
            Spacer()
            Button { calendarService.deleteBlock(block) } label: {
                Image(systemName: "xmark").frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quitar bloque")
        }
        .foregroundStyle(ProjectPalette.foreground(colorIndex))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ProjectPalette.fill(colorIndex), in: RoundedRectangle(cornerRadius: 10))
    }

    private var sortedEntries: [TimeEntry] { task.timeEntries.sorted { $0.start < $1.start } }

    private var timeSection: some View {
        let now = timeTracker.now
        let total = PlannerFormat.hoursMinutes(task.trackedMinutes(now: now))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tiempo registrado").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(task.estimateMinutes.map { "\(total) de \(PlannerFormat.hours(minutes: $0))" } ?? total)
                    .font(.system(size: 13, design: .monospaced))
            }
            if let running = timeTracker.running, timeTracker.isRunning(task) {
                HStack(spacing: 10) {
                    Circle().fill(Theme.accentText).frame(width: 8, height: 8)
                    Text("Cronómetro en curso desde las \(PlannerFormat.time(running.start)) · también puedes detenerlo desde la barra de menú")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Detener") { timeTracker.stop() }
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.accentText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.accentText.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            ForEach(sortedEntries) { entry in
                entryRow(entry, now: now)
            }
            if let timeEditError {
                Text(timeEditError).font(.system(size: 12)).foregroundStyle(Theme.urgentHigh)
            }
            HStack(spacing: 8) {
                if !timeTracker.isRunning(task) {
                    Button { timeTracker.start(task) } label: {
                        Label("Retomar cronómetro", systemImage: "play.fill")
                    }
                }
                Button("+ Registro manual") { timeTracker.addManualEntry(to: task) }
            }
        }
    }

    private func entryRow(_ entry: TimeEntry, now: Date) -> some View {
        HStack(spacing: 8) {
            Text("\(PlannerFormat.weekday(entry.start)) \(PlannerFormat.day(entry.start))")
                .foregroundStyle(Theme.muted)
                .frame(width: 68, alignment: .leading)
            DatePicker("Inicio", selection: entryTime(entry, isStart: true), displayedComponents: .hourAndMinute)
                .labelsHidden()
            Text("–").foregroundStyle(Theme.muted)
            if entry.end == nil {
                Text("en curso").foregroundStyle(Theme.muted)
            } else {
                DatePicker("Fin", selection: entryTime(entry, isStart: false), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            Text(PlannerFormat.hoursMinutes(entry.minutes(now: now)))
                .font(.system(size: 13, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .trailing)
            Button { timeTracker.delete(entry) } label: {
                Image(systemName: "xmark").frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.muted)
            .accessibilityLabel("Borrar registro")
        }
        .font(.system(size: 13))
        .environment(\.locale, .planner)
    }

    /// Edits the start or end of an entry; an end before its start is rejected and the previous value is kept.
    private func entryTime(_ entry: TimeEntry, isStart: Bool) -> Binding<Date> {
        Binding(
            get: { isStart ? entry.start : entry.end ?? .now },
            set: { newValue in
                let accepted = isStart ? timeTracker.update(entry, start: newValue) : timeTracker.update(entry, end: newValue)
                timeEditError = accepted ? nil : "El fin no puede ser anterior al inicio; se mantiene el valor anterior."
            }
        )
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas").font(.system(size: 14, weight: .semibold))
            TextEditor(text: $task.notes)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 120)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.control))
        }
    }

    /// Places the unscheduled part of the estimate in the first free slot from now, within the next two weeks.
    private func scheduleRemaining() {
        let duration = TimeInterval(remainingMinutes * 60)
        let settings = settingsStore.settings
        let calendar = Calendar.planner
        let today = calendar.startOfDay(for: .now)
        let nowSnapped = today.addingTimeInterval(TimeInterval(SlotFinder.snap(minutes: Int(Date.now.timeIntervalSince(today) / 60) + SlotFinder.stepMinutes - 1) * 60))
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let workday = settings.workday(containing: day) else { continue }
            let busy = calendarService.busyIntervals(on: day)
            let earliest = max(workday.start, nowSnapped)
            guard earliest.addingTimeInterval(duration) <= workday.end else { continue }
            if let start = SlotFinder.nextFreeStart(from: earliest, duration: duration, busy: busy, workday: workday) {
                calendarService.createBlock(for: task, start: start, end: start.addingTimeInterval(duration))
                return
            }
        }
        calendarService.otherErrorMessage = "No hay un hueco libre de \(PlannerFormat.hours(minutes: remainingMinutes)) en las próximas dos semanas."
    }
}
