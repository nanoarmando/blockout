import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(UpdateCoordinator.self) private var updates
    @Environment(TimeTracker.self) private var timeTracker
    static let windowID = "about"
    private static let repository = URL(string: "https://github.com/nanoarmando/blockout")!

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 80, height: 80)
            Text("Blockout").font(.title.bold())
            Text("Versión \(info("CFBundleShortVersionString")) (\(info("CFBundleVersion")))").foregroundStyle(.secondary)
            Text("Blockout es software libre bajo la licencia GNU GPL-3.0, sin ninguna garantía.")
                .font(.callout)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Código fuente", destination: Self.repository).pointerStyle(.link)
                Link("Licencia", destination: Self.repository.appending(path: "blob/main/LICENSE")).pointerStyle(.link)
            }
            Divider()
            UpdatesSection(updates: updates, isTimerRunning: timeTracker.running != nil)
        }
        .padding(24)
        .frame(width: 440)
        .onAppear { updates.check() }
    }

    private func info(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "dev"
    }
}

/// The result of the last update check, the release notes of a newer version and its install button.
private struct UpdatesSection: View {
    let updates: UpdateCoordinator
    let isTimerRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            status
            if case .available(let update) = updates.state {
                ScrollView {
                    Text(Self.markdown(update.notes))
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140)
                installRow(update)
            }
            if let error = updates.installError {
                Text(error).font(.callout).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var status: some View {
        HStack {
            switch updates.state {
            case .idle, .checking:
                ProgressView().controlSize(.small)
                Text("Buscando actualizaciones…").foregroundStyle(.secondary)
            case .unavailable(let reason):
                Text(reason).foregroundStyle(.secondary)
            case .upToDate:
                Label("Blockout está actualizado", systemImage: "checkmark.circle")
            case .available(let update):
                Label("Blockout \(update.version.description) está disponible", systemImage: "arrow.down.circle")
            case .downloading(let update, let fraction):
                ProgressView(value: fraction).frame(width: 120)
                Text("Descargando \(update.version.description)…").foregroundStyle(.secondary)
            case .verifying(let update):
                ProgressView().controlSize(.small)
                Text("Verificando \(update.version.description)…").foregroundStyle(.secondary)
            case .failed(let message):
                Label("No se pudo completar la búsqueda de actualizaciones: \(message)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if case .failed = updates.state {
                Button("Reintentar") { updates.check() }
            } else if !updates.isWorking, UpdateEligibility.current != .developmentBuild {
                Button("Buscar actualizaciones") { updates.check() }
            }
        }
    }

    @ViewBuilder private func installRow(_ update: AvailableUpdate) -> some View {
        HStack {
            if let refusal = UpdateEligibility.current.refusal {
                Text(refusal).font(.callout).foregroundStyle(.secondary)
                Spacer()
                Link("Página de la versión", destination: update.pageURL).pointerStyle(.link)
            } else {
                if isTimerRunning {
                    Text("Detén el temporizador antes de instalar").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Link("Página de la versión", destination: update.pageURL).pointerStyle(.link)
                Button("Instalar actualización") { updates.install(update) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isTimerRunning)
            }
        }
    }

    private static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// "Acerca de Blockout" and, when a newer release is known, "Actualización disponible"; used by the app menu and
/// the menu bar menu.
struct AboutMenuItems: View {
    @Environment(UpdateCoordinator.self) private var updates
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Acerca de Blockout", action: openAbout)
        if let version = updates.availableVersion {
            Button("Actualización disponible (\(version.description))…", action: openAbout)
        }
    }

    private func openAbout() {
        openWindow(id: AboutView.windowID)
        NSApp.activate()
    }
}
