import AppKit
import SwiftUI

/// Mode avancé : les fichiers de configuration d'un jeu, à modifier ou à
/// réinitialiser. Tous sont dans le dossier utilisateur ; ceux que Borne
/// réécrit à chaque lancement (autoexec.cfg, borne.cfg) n'y figurent pas.
enum ConfigFiles {
    static let advancedKey = "advancedMode"

    struct File: Identifiable, Hashable {
        var id: String { url.path }
        let url: URL
        /// Fichier partagé par d'autres jeux du même moteur.
        var shared: String?
    }

    static func files(for m: Machine) -> [File] {
        let fm = FileManager.default
        guard let engine = m.engineKind else {
            // MAME : réglages du jeu, puis ceux communs à tous les jeux (touches).
            let dir = Prefs.userDataRoot.appendingPathComponent("cfg")
            return [File(url: dir.appendingPathComponent("\(m.name).cfg")),
                    File(url: dir.appendingPathComponent("default.cfg"), shared: String(localized: "commun à tous les jeux d'arcade"))]
                .filter { fm.fileExists(atPath: $0.url.path) }
        }
        if engine == .dos {
            let conf = dosConf(for: m)
            return fm.fileExists(atPath: conf.path) ? [File(url: conf)] : []
        }
        let user = engine.userDirectory
        let home = user.appendingPathComponent("home")
        let all = String(localized: "commun aux jeux \(engine.title)")
        var dirs: [(URL, String?)]
        switch engine {
        case .doom: dirs = [(user, all)]
        case .build: dirs = [(user, all)]
        case .wolf3d: dirs = [(user, all)]
        case .scummvm: dirs = [(user, all)]
        case .quake: dirs = [(user.appendingPathComponent(m.modArg ?? "id1"), nil), (user, all)]
        case .quake3: dirs = [(user.appendingPathComponent(m.modArg ?? "baseq3"), nil)]
        case .rtcw: dirs = [(user.appendingPathComponent("main"), nil)]
        case .quake2: dirs = [(home.appendingPathComponent(".yq2/\(m.modArg ?? "baseq2")"), nil)]
        case .doom3: dirs = [(user.appendingPathComponent("saves/\(m.modArg ?? "base")"), nil)]
        case .quake4: dirs = [(user.appendingPathComponent("baseoq4"), nil)]
        case .dos: dirs = []
        }
        let generated: Set<String> = ["autoexec.cfg", "borne.cfg"]
        var out: [File] = []
        for (dir, shared) in dirs {
            let items = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
            for item in items.sorted() where ["cfg", "ini", "conf"].contains((item as NSString).pathExtension.lowercased())
                && !generated.contains(item.lowercased()) {
                out.append(File(url: dir.appendingPathComponent(item), shared: shared))
            }
        }
        return out
    }

    // MARK: DOSBox, par jeu

    /// Réglages DOSBox propres à un jeu, lus à chaque lancement s'ils existent.
    static func dosConf(for m: Machine) -> URL {
        Engine.dos.userDirectory.appendingPathComponent("conf/\(m.name.replacingOccurrences(of: "dos:", with: "")).conf")
    }

    static func createDOSConf(for m: Machine) throws -> URL {
        let url = dosConf(for: m)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let header = String(localized: "Réglages DOSBox Staging pour \(m.description), lus par Borne à chaque lancement.")
        let howTo = String(localized: "Retirez le # d'une ligne pour l'activer. Toutes les options :")
        let cpu = String(localized: "Vitesse du processeur émulé (jeux en mode réel, puis en mode protégé)")
        let render = String(localized: "Aspect d'un écran cathodique : crt-auto, sharp, bilinear…")
        let sound = String(localized: "Carte son : sb16, sbpro2, sb1, gus…")
        let video = String(localized: "Carte vidéo : svga_s3, vga, ega, cga, tandy…")
        let text = """
        # \(header)
        # \(howTo)
        # https://www.dosbox-staging.org/manual/

        [cpu]
        # \(cpu)
        # cpu_cycles = 3000
        # cpu_cycles_protected = 60000

        [render]
        # \(render)
        # shader = crt-auto
        # aspect = auto

        [sblaster]
        # \(sound)
        # sbtype = sb16

        [mixer]
        # reverb = medium
        # chorus = normal

        [dosbox]
        # \(video)
        # machine = svga_s3
        # memsize = 16

        """
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

/// Section « Configuration » de la fiche d'un jeu, en mode avancé.
struct ConfigFilesSection: View {
    @Environment(Catalog.self) private var catalog
    let machine: Machine
    @State private var editing: ConfigFiles.File?
    @State private var resetting: ConfigFiles.File?
    @State private var generation = 0

    var body: some View {
        let _ = generation
        let _ = catalog.settingsGeneration
        let files = ConfigFiles.files(for: machine)
        VStack(alignment: .leading, spacing: 6) {
            Text("Configuration").font(.headline).padding(.top, 6)
            if files.isEmpty {
                (machine.engineKind == .dos
                     ? Text("Pas de réglages DOSBox propres à ce jeu : il utilise ceux de Borne.")
                     : Text("Pas encore de fichier : le moteur le crée au premier lancement du jeu."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(files) { file in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(file.url.lastPathComponent).font(.callout.monospaced())
                        if let shared = file.shared {
                            Text(shared.prefix(1).uppercased() + shared.dropFirst()).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Modifier…") { editing = file }
                    Button("Réinitialiser…") { resetting = file }
                }
                .controlSize(.small)
            }
            if machine.engineKind == .dos && files.isEmpty {
                Button("Créer des réglages DOSBox pour ce jeu") {
                    if let url = try? ConfigFiles.createDOSConf(for: machine) {
                        generation += 1
                        editing = ConfigFiles.File(url: url)
                    }
                }
                .controlSize(.small)
            }
        }
        .sheet(item: $editing) { file in
            ConfigEditor(file: file, gameRunning: catalog.running != nil) { generation += 1 }
        }
        .confirmationDialog("Réinitialiser \(resetting?.url.lastPathComponent ?? "") ?",
                            isPresented: Binding(get: { resetting != nil }, set: { if !$0 { resetting = nil } }),
                            presenting: resetting) { file in
            Button("Réinitialiser") {
                try? FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                generation += 1
            }
        } message: { file in
            Text((file.shared.map { String(localized: "Ce fichier est \($0). ") } ?? "")
                 + String(localized: "Il va à la Corbeille ; le moteur repart de ses réglages d'origine au prochain lancement. Sauvegardes et scores sont gardés."))
        }
    }
}

/// Éditeur de texte d'un fichier de configuration.
struct ConfigEditor: View {
    let file: ConfigFiles.File
    let gameRunning: Bool
    let saved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var original = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(file.url.lastPathComponent).font(.headline)
                Spacer()
                Button("Afficher dans le Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                    .controlSize(.small)
            }
            if gameRunning {
                Text("Un jeu est en cours : le moteur peut réécrire ce fichier en quittant. Enregistrez une fois le jeu fermé.")
                    .font(.callout).foregroundStyle(.orange)
            } else if let shared = file.shared {
                Text("Ce fichier est \(shared).").font(.callout).foregroundStyle(.secondary)
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .frame(minWidth: 620, minHeight: 420)
            if let error { Text(error).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Enregistrer") {
                    do {
                        try text.write(to: file.url, atomically: true, encoding: .utf8)
                        saved()
                        dismiss()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text == original)
            }
        }
        .padding()
        .onAppear {
            // Latin-1 en secours : certains moteurs écrivent des accents hors UTF-8.
            let data = (try? Data(contentsOf: file.url)) ?? Data()
            text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            original = text
        }
    }
}
