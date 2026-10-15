import SwiftData
import SwiftUI

/// Which project the sheet creates or edits.
enum ProjectSheetTarget: Identifiable {
    case new
    case edit(Project)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let project): project.id.uuidString
        }
    }
}

/// Creates or edits a project: name (unique case-insensitively) and palette color.
struct ProjectSheet: View {
    let target: ProjectSheetTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarService.self) private var calendarService
    @Query private var projects: [Project]
    @State private var name = ""
    @State private var colorIndex = 0
    @State private var error: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var editedProject: Project? {
        if case .edit(let project) = target { project } else { nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editedProject == nil ? "Nuevo proyecto" : "Editar proyecto").font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 6) {
                Text("Nombre").font(.system(size: 12)).foregroundStyle(Theme.muted)
                TextField("Nombre del proyecto", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                    .onChange(of: name) { error = nil }
                if let error {
                    Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Color").font(.system(size: 12)).foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    ForEach(0..<ProjectPalette.count, id: \.self) { index in
                        Button { colorIndex = index } label: {
                            Circle()
                                .fill(ProjectPalette.fill(index))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: colorIndex == index ? 2 : 0).padding(-3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 3)
            }
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Guardar", action: save).keyboardShortcut(.defaultAction).disabled(trimmedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            if let project = editedProject {
                name = project.name
                colorIndex = project.colorIndex
            } else {
                colorIndex = projects.count % ProjectPalette.count
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let taken = projects.contains { $0.id != editedProject?.id && $0.name.compare(trimmedName, options: .caseInsensitive) == .orderedSame }
        guard !taken else {
            error = "Ya existe un proyecto con ese nombre."
            return
        }
        var renamed: Project?
        if let project = editedProject {
            if project.name != trimmedName { renamed = project }
            project.name = trimmedName
            project.colorIndex = colorIndex
        } else {
            modelContext.insert(Project(name: trimmedName, colorIndex: colorIndex))
        }
        try? modelContext.save()
        // Block events carry "[Project] Title", so a rename retitles every event of the project's tasks
        if let renamed { calendarService.syncEventTitles(of: renamed.tasks) }
        dismiss()
    }
}
