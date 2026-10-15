import SwiftData
import SwiftUI

struct MainView: View {
    @Query(sort: \PlannerTask.createdAt, order: .reverse) private var allTasks: [PlannerTask]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query private var blocks: [Block]

    @Environment(CalendarService.self) private var calendarService
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.openSettings) private var openSettings

    @State private var filter = TaskFilter.all
    @State private var range = CalendarRange()
    @State private var events: [CalendarEvent] = []
    @State private var selectedTask: PlannerTask?

    private var openTasks: [PlannerTask] { allTasks.filter(\.isOpen) }
    private var confirmedBlocks: [Block] { blocks.filter { !$0.isDraft } }
    private var drafts: [Block] { blocks.filter(\.isDraft).sorted { $0.start < $1.start } }

    var body: some View {
        @Bindable var calendarService = calendarService
        VStack(spacing: 0) {
            CalendarHeader(range: $range)
            HStack(spacing: 0) {
                SidebarView(filter: $filter, openTasks: openTasks, projects: projects)
                Theme.line.frame(width: 1)
                TaskListView(tasks: openTasks.filter(filter.matches), projects: projects) { selectedTask = $0 }
                Theme.line.frame(width: 1)
                calendarArea
            }
        }
        .background(Theme.background)
        .foregroundStyle(Theme.ink)
        .frame(minWidth: 1180, minHeight: 640)
        .task(id: EventsKey(range: range.fetchInterval, revision: calendarService.revision, settings: settingsStore.settings, hasAccess: calendarService.hasAccess)) {
            events = calendarService.events(in: range.fetchInterval)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task, projects: projects)
        }
        .alert(
            "No se pudo guardar el bloque",
            isPresented: Binding(get: { calendarService.writeError != nil }, set: { if !$0 { calendarService.writeError = nil } }),
            presenting: calendarService.writeError
        ) { error in
            if case .destinationUnavailable = error {
                Button("Abrir Ajustes") { openSettings() }
            }
            Button("Aceptar", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "")
        }
        .alert(
            "No se pudo completar la acción",
            isPresented: Binding(get: { calendarService.otherErrorMessage != nil }, set: { if !$0 { calendarService.otherErrorMessage = nil } }),
            presenting: calendarService.otherErrorMessage
        ) { _ in
            Button("Aceptar", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var calendarArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            if calendarService.authorization == .notDetermined {
                Spacer()
            } else if !calendarService.hasAccess {
                Spacer()
                CalendarAccessNotice()
                Spacer()
            } else {
                legend
                let drafts = drafts
                if !drafts.isEmpty {
                    DraftBanner(drafts: drafts)
                }
                if range.mode == .month {
                    MonthGridView(cells: range.monthCells, month: range.anchor, events: events, blocks: confirmedBlocks)
                } else {
                    TimeGridView(days: range.days, events: events, blocks: confirmedBlocks, drafts: drafts, tasks: allTasks) { selectedTask = $0 }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                    .frame(width: 12, height: 12)
                Text("Evento de calendario (solo lectura)")
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(ProjectPalette.fill(0)).frame(width: 12, height: 12)
                Text(settingsStore.settings.blocksShowAsBusy ? "Bloque de tarea · te marca como ocupado" : "Bloque de tarea · se muestra como disponible")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.muted)
    }
}

private struct EventsKey: Equatable {
    let range: DateInterval
    let revision: Int
    let settings: AppSettings
    let hasAccess: Bool
}

/// Navigation, range title and the Día / Días / Semana / Mes control.
private struct CalendarHeader: View {
    @Binding var range: CalendarRange
    @State private var showsDayCount = false

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                AppMark().frame(width: 22, height: 22)
                Text("Blockout").font(.system(size: 16, weight: .semibold))
            }
            .frame(minWidth: 200, alignment: .leading)
            HStack(spacing: 8) {
                navButton("chevron.left", label: "Anterior") { range.step(-1) }
                Button("Hoy") { range.goToToday() }
                    .buttonStyle(ToggleButtonStyle(isSelected: false, height: 36))
                navButton("chevron.right", label: "Siguiente") { range.step(1) }
                Text(range.title).font(.system(size: 18, weight: .semibold)).padding(.leading, 8)
            }
            Spacer()
            HStack(spacing: 0) {
                segment("Día", mode: .day) { range.mode = .day }
                segment(range.mode == .days ? "\(range.dayCount) días ▾" : "Días ▾", mode: .days) { showsDayCount.toggle() }
                    .popover(isPresented: $showsDayCount, arrowEdge: .bottom) { dayCountPicker }
                segment("Semana", mode: .week) { range.mode = .week }
                segment("Mes", mode: .month) { range.mode = .month }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.control))
            SettingsLink {
                Image(systemName: "gearshape").frame(width: 36, height: 36)
            }
            .buttonStyle(ToggleButtonStyle(isSelected: false, height: 36))
            .help("Ajustes")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    private func navButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 12)
        }
        .buttonStyle(ToggleButtonStyle(isSelected: false, height: 36))
        .foregroundStyle(Theme.secondary)
        .accessibilityLabel(label)
    }

    private func segment(_ title: String, mode: CalendarMode, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(ToggleButtonStyle(isSelected: range.mode == mode, height: 36, bordered: false))
    }

    private var dayCountPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cantidad de días desde hoy").font(.system(size: 13)).foregroundStyle(Theme.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(2...7, id: \.self) { count in
                    let isSelected = range.mode == .days && range.dayCount == count
                    Button("\(count)") {
                        range.mode = .days
                        range.dayCount = count
                        range.goToToday()
                        showsDayCount = false
                    }
                    .buttonStyle(ToggleButtonStyle(isSelected: isSelected, height: 40))
                }
            }
        }
        .padding(12)
        .frame(width: 220)
    }
}

/// The B1 mark: three staggered time bars with the current block in teal, crossed by the red now line.
struct AppMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 200
            func bar(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ color: Color) {
                let rect = CGRect(x: x * scale, y: y * scale, width: width * scale, height: 22 * scale)
                context.fill(Path(roundedRect: rect, cornerRadius: 11 * scale), with: .color(color))
            }
            context.fill(Path(roundedRect: CGRect(x: 10 * scale, y: 10 * scale, width: 180 * scale, height: 180 * scale), cornerRadius: 42 * scale), with: .color(Color(hex: 0x1F1F1D)))
            bar(40, 52, 70, Color(hex: 0x3E3D3A))
            bar(66, 89, 94, Color(hex: 0x14B8A6))
            bar(52, 126, 56, Color(hex: 0x3E3D3A))
            var line = Path()
            line.move(to: CGPoint(x: 128 * scale, y: 38 * scale))
            line.addLine(to: CGPoint(x: 128 * scale, y: 162 * scale))
            context.stroke(line, with: .color(Color(hex: 0xFF5A5F)), style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: 120 * scale, y: 30 * scale, width: 16 * scale, height: 16 * scale)), with: .color(Color(hex: 0xFF5A5F)))
        }
        .accessibilityHidden(true)
    }
}

/// Shown while drafts exist: how many blocks are proposed, with "Descartar" and "Aceptar todo".
private struct DraftBanner: View {
    let drafts: [Block]

    @Environment(CalendarService.self) private var calendarService

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(drafts.count == 1 ? "1 bloque propuesto" : "\(drafts.count) bloques propuestos")
                    .font(.system(size: 14, weight: .semibold))
                Text("Nada se escribe en el calendario hasta que aceptes. Selecciona un bloque propuesto para aceptarlo o descartarlo por separado.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 12)
            Button("Descartar") { calendarService.discardDrafts(drafts) }
                .buttonStyle(ToggleButtonStyle(isSelected: false, height: 36))
            Button("Aceptar todo") { calendarService.acceptDrafts(drafts) }
                .buttonStyle(ToggleButtonStyle(isSelected: true, selectedFill: Theme.accent, selectedText: .white, height: 36))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.banner, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
        .accessibilityElement(children: .contain)
    }
}
