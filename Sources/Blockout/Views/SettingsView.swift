import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(CalendarService.self) private var calendarService
    @Environment(MCPServer.self) private var mcpServer
    @Environment(\.openWindow) private var openWindow
    @State private var showsPicker = false

    var body: some View {
        @Bindable var settingsStore = settingsStore
        VStack(alignment: .leading, spacing: 18) {
            section("Calendario") {
                if calendarService.hasAccess {
                    settingRow {
                        Text("Escribir los bloques en")
                        Spacer()
                        Picker("Escribir los bloques en", selection: $settingsStore.settings.destinationCalendarID) {
                            if settingsStore.settings.destinationCalendarID == nil {
                                Text("Elegir…").tag(String?.none)
                            }
                            ForEach(calendarService.writableCalendars) { calendar in
                                Text(calendar.displayName).tag(Optional(calendar.id))
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    Divider()
                    settingRow {
                        Text("Mostrar los bloques como")
                        Spacer()
                        Picker("Mostrar los bloques como", selection: $settingsStore.settings.blocksShowAsBusy) {
                            Text("Ocupado").tag(true)
                            Text("Disponible").tag(false)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    Divider()
                    settingRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendarios que se leen")
                            Text(readSummary)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer()
                        Button("Elegir…") { showsPicker = true }
                    }
                } else {
                    CalendarAccessNotice()
                        .padding(.vertical, 12)
                }
            }
            section("Jornada") {
                HStack(alignment: .top, spacing: 16) {
                    timeField("Inicio", minutes: $settingsStore.settings.workdayStartMinutes)
                    timeField("Fin", minutes: $settingsStore.settings.workdayEndMinutes)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bloque por defecto").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Picker("Bloque por defecto", selection: $settingsStore.settings.defaultBlockLength) {
                            ForEach(DefaultBlockLength.allCases) { length in
                                Text(length.label).tag(length)
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)
            }
            section("Integraciones") {
                mcpRows
            }
            section("Blockout") {
                settingRow {
                    Text("Versión, licencia y actualizaciones")
                    Spacer()
                    Button("Acerca de Blockout…") {
                        openWindow(id: AboutView.windowID)
                        NSApp.activate()
                    }
                }
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: 620)
        .background(Theme.background)
        .sheet(isPresented: $showsPicker) {
            CalendarPickerView()
        }
        .onChange(of: MCPConfiguration(settingsStore.settings)) { _, configuration in
            mcpServer.configure(enabled: configuration.enabled, port: configuration.port)
        }
    }

    @ViewBuilder
    private var mcpRows: some View {
        @Bindable var settingsStore = settingsStore
        settingRow {
            Circle().fill(mcpServer.status == .active ? Theme.ok : Theme.barOff).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("Servidor MCP")
                Text("\(mcpServer.address) · \(mcpStatusLabel)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("Copiar") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(mcpServer.address, forType: .string)
            }
            Toggle("Servidor MCP", isOn: $settingsStore.settings.mcpEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        Divider()
        settingRow {
            VStack(alignment: .leading, spacing: 2) {
                Text("Puerto")
                if mcpServer.status == .portBusy {
                    Text("Puerto ocupado por otra aplicación. Elige otro puerto.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                }
            }
            Spacer()
            TextField("Puerto", value: $settingsStore.settings.mcpPort, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }

    private var mcpStatusLabel: String {
        switch mcpServer.status {
        case .off: "Apagado"
        case .starting: "Iniciando…"
        case .active: "Activo"
        case .portBusy: "Puerto ocupado"
        case .failed(let message): "Error: \(message)"
        }
    }

    private var readSummary: String {
        let all = calendarService.calendars
        let selected = all.filter { settingsStore.settings.readCalendarIDs?.contains($0.id) ?? true }
        let names = selected.isEmpty ? "ninguno" : selected.map(\.title).joined(separator: ", ")
        return "\(selected.count) de \(all.count) · \(names)"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
            VStack(spacing: 0, content: content)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
        }
    }

    private func settingRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 16, content: content).frame(minHeight: 52)
    }

    /// Edits a time of day stored as minutes since midnight; the end is kept after the start.
    private func timeField(_ title: String, minutes: Binding<Int>) -> some View {
        let calendar = Calendar.planner
        let today = calendar.startOfDay(for: .now)
        let date = Binding<Date>(
            get: { today.addingTimeInterval(TimeInterval(minutes.wrappedValue * 60)) },
            set: { newValue in
                let parts = calendar.dateComponents([.hour, .minute], from: newValue)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                var settings = settingsStore.settings
                if settings.workdayEndMinutes <= settings.workdayStartMinutes {
                    settings.workdayEndMinutes = min(24 * 60, settings.workdayStartMinutes + 60)
                    settings.workdayStartMinutes = settings.workdayEndMinutes - 60
                    settingsStore.settings = settings
                }
            }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.muted)
            DatePicker(title, selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "es"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Picker of the calendars that are read: search, groups by account, "Todos"/"Ninguno" per account and a count.
struct CalendarPickerView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var selection: Set<String> {
        settingsStore.settings.readCalendarIDs ?? Set(calendarService.calendars.map(\.id))
    }

    private var accounts: [(name: String, calendars: [CalendarInfo])] {
        Dictionary(grouping: calendarService.calendars, by: \.accountTitle)
            .map { ($0.key, $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Calendarios que se leen").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("\(selection.count) de \(calendarService.calendars.count) seleccionados")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                TextField("Buscar calendario", text: $search)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(accounts, id: \.name) { account in
                        accountGroup(account.name, calendars: account.calendars)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }
            Divider()
            HStack {
                Spacer()
                Button("Listo") { dismiss() }
                    .buttonStyle(ToggleButtonStyle(isSelected: true, height: 34))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(width: 460, height: 520)
        .background(Theme.card)
    }

    @ViewBuilder
    private func accountGroup(_ name: String, calendars: [CalendarInfo]) -> some View {
        let needle = search.trimmingCharacters(in: .whitespaces)
        let visible = needle.isEmpty ? calendars : calendars.filter { $0.title.localizedCaseInsensitiveContains(needle) }
        if !visible.isEmpty {
            let ids = Set(calendars.map(\.id))
            let allSelected = ids.isSubset(of: selection)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
                    Spacer()
                    Button(allSelected ? "Ninguno" : "Todos") {
                        update(allSelected ? selection.subtracting(ids) : selection.union(ids))
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accentText)
                }
                .padding(.vertical, 6)
                ForEach(visible) { calendar in
                    Toggle(isOn: Binding(
                        get: { selection.contains(calendar.id) },
                        set: { isOn in update(isOn ? selection.union([calendar.id]) : selection.subtracting([calendar.id])) }
                    )) {
                        HStack(spacing: 10) {
                            Circle().fill(calendar.color).frame(width: 10, height: 10)
                            Text(calendar.title)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .frame(minHeight: 34)
                }
            }
        }
    }

    private func update(_ ids: Set<String>) {
        settingsStore.settings.readCalendarIDs = ids
    }
}

/// Shown instead of the calendar when access was denied; task management keeps working.
struct CalendarAccessNotice: View {
    @Environment(CalendarService.self) private var calendarService

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark").font(.system(size: 32)).foregroundStyle(Theme.muted)
            Text("Blockout necesita acceso a tus calendarios").font(.system(size: 15, weight: .semibold))
            Text("Con el acceso puedes ver tus eventos y reservar el tiempo de tus tareas como ocupado. Mientras tanto puedes seguir creando y editando tareas.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Abrir Ajustes del Sistema") { calendarService.openPrivacySettings() }
                .buttonStyle(ToggleButtonStyle(isSelected: true, height: 36))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MCPConfiguration: Equatable {
    let enabled: Bool
    let port: Int

    init(_ settings: AppSettings) {
        enabled = settings.mcpEnabled
        port = settings.mcpPort
    }
}
