import SwiftUI

/// Section « Diagnostic » de la fiche : ce qui est là, ce qui manque, et un bouton
/// quand Borne peut compléter lui-même.
struct DiagnosticView: View {
    @Environment(Catalog.self) private var catalog
    @Environment(\.openSettings) private var openSettings
    let machine: Machine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Diagnostic").font(.headline)
                Spacer()
                if machine.engineKind == nil {
                    if catalog.diagnosing == machine.name {
                        ProgressView().controlSize(.small)
                    } else if catalog.diagnostics[machine.name] == nil {
                        Button("Diagnostiquer") { catalog.diagnose(machine.name) }
                            .controlSize(.small)
                            .help("MAME liste les fichiers dont le jeu a besoin et vérifie chacun")
                    }
                }
            }
            ForEach(items) { item in
                row(item)
            }
            if machine.engineKind == nil && catalog.diagnostics[machine.name] == nil && catalog.diagnosing != machine.name {
                Text("Vérifie le jeu, son original, son BIOS, ses périphériques et ses sons, et dit comment compléter ce qui manque.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Jeux PC : recalculé à chaque affichage (fichiers seulement), après chaque téléchargement.
    private var items: [DiagnosticItem] {
        if machine.engineKind != nil {
            let _ = catalog.modulesGeneration
            let _ = catalog.job
            return Diagnostic.engineGame(machine)
        }
        return catalog.diagnostics[machine.name] ?? []
    }

    private func row(_ item: DiagnosticItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol(item.state))
                .foregroundStyle(color(item.state))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.callout.weight(.medium))
                if let detail = item.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let fix = item.fix, item.state != .ok || fix == .verify || fix == .revealUserData {
                    Button(fix.label) {
                        if fix == .showSettings { openSettings() } else { catalog.perform(fix, for: machine.name) }
                    }
                    .controlSize(.small)
                    .disabled(catalog.job != nil && fix != .revealUserData && fix != .showSettings)
                }
            }
        }
    }

    private func symbol(_ s: DiagnosticItem.State) -> String {
        switch s {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .missing: "xmark.circle.fill"
        case .info: "info.circle"
        }
    }

    private func color(_ s: DiagnosticItem.State) -> Color {
        switch s {
        case .ok: .green
        case .warning: .orange
        case .missing: .red
        case .info: .secondary
        }
    }
}
