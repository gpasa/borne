import SwiftUI

/// Volet de droite : image et fiche, comme le panneau d'images de MAMEUI.
struct GameDetail: View {
    @Environment(Catalog.self) private var catalog
    @AppStorage("pictureKind") private var kind: PictureKind = .snap
    @State private var image: NSImage?
    @State private var imageKey = ""
    @State private var confirmReset = false
    @AppStorage(ConfigFiles.advancedKey) private var advanced = false

    var body: some View {
        if let m = catalog.selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let engine = m.engineKind {
                        engineHeader(engine)
                    } else {
                    Picker("Image", selection: $kind) {
                        ForEach(PictureKind.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()

                    picture(m)
                        .task(id: "\(m.name)/\(kind.rawValue)") {
                            // Lu hors du fil principal : le disque des jeux peut être lent.
                            let key = "\(m.name)/\(kind.rawValue)"
                            let data = await kind.imageData(for: m)
                            guard !Task.isCancelled else { return }
                            image = data.flatMap(NSImage.init(data:))
                            imageKey = key
                        }
                    }

                    Text(m.description).font(.title3.bold())
                    Text("\(m.manufacturer), \(m.year)").foregroundStyle(.secondary)

                    HStack {
                        Button {
                            catalog.launch(m.name)
                        } label: {
                            Label("Lancer", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(catalog.running != nil)
                        Button {
                            catalog.toggleFavorite(m.name)
                        } label: {
                            Label("Favori", systemImage: catalog.favorites.contains(m.name) ? "star.fill" : "star")
                        }
                    }

                    if catalog.isLocal(m.name) {
                        HStack {
                            Label("Installé sur ce Mac", systemImage: "laptopcomputer")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Supprimer la copie") { catalog.uninstall(m.name) }
                                .controlSize(.small)
                        }
                    } else if catalog.available.contains(m.name) && m.needsFiles {
                        Button {
                            catalog.proposeInstall([m.name])
                        } label: {
                            Label("Installer sur ce Mac…", systemImage: "square.and.arrow.down")
                        }
                        .disabled(catalog.job != nil)
                        .help("Copie le jeu et ce dont il a besoin, pour jouer sans le disque des jeux")
                    }

                    if let engine = m.engineKind {
                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 5) {
                            info("Moteur", engine.engineName)
                            if engine == .quake { info("Rendu", "Vulkan · \(Engine.vulkanDriverName)") }
                            if let mod = m.modArg, engine == .doom {
                                info("Fichier", (mod as NSString).lastPathComponent)
                                info("Jeu de base", ((m.dataPath ?? "") as NSString).lastPathComponent)
                            } else if let path = m.dataPath {
                                info(engine == .doom ? "Fichier" : "Dossier", (path as NSString).lastPathComponent)
                            }
                            if let game = m.modArg, engine == .quake { info("Extension", game) }
                            info("Emplacement", (m.dataPath ?? "") as String)
                            info("Sauvegardes", String(localized: "Dossier utilisateur, jamais sur le disque des jeux"))
                        }
                        .font(.callout)
                    } else {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 5) {
                        info("Nom court", m.name)
                        if let p = m.cloneOf {
                            info("Original", catalog.machines[p]?.description ?? p)
                        }
                        info("Pilote", m.sourcefile)
                        info("État", m.statusLabel)
                        info("Sauvegarde", m.savestate ? String(localized: "Prise en charge") : String(localized: "Non"))
                        info("ROM", romText(m))
                        if !m.screen.isEmpty {
                            info("Écran", screenText(m))
                        }
                        if m.players > 0 {
                            info("Joueurs", "\(m.players)")
                        }
                        if !m.controls.isEmpty {
                            info("Commandes", m.controls.joined(separator: ", ")
                                 + (m.buttons > 0 ? " · " + String(localized: "\(m.buttons) boutons") : ""))
                        }
                        if !m.cpus.isEmpty {
                            info("Processeurs", m.cpus.joined(separator: ", "))
                        }
                    }
                    .font(.callout)
                    }

                    DiagnosticView(machine: m)
                        .padding(.top, 4)

                    let _ = catalog.settingsGeneration
                    if catalog.hasDisplaySettings(m.name) {
                        Button {
                            catalog.resetDisplay(m.name)
                        } label: {
                            Label("Réinitialiser l'affichage", systemImage: "rectangle.dashed")
                        }
                        .help("Position, échelle et vue de l'écran ; touches et volume restent")
                    }
                    if catalog.hasSettings(m.name) {
                        Button {
                            confirmReset = true
                        } label: {
                            Label("Réinitialiser tous les réglages…", systemImage: "arrow.counterclockwise")
                        }
                        .controlSize(.small)
                        .help("Écran, touches et volume tels que MAME les a enregistrés pour ce jeu")
                        .confirmationDialog("Réinitialiser les réglages de \(m.description) ?",
                                            isPresented: $confirmReset) {
                            Button("Réinitialiser") { catalog.resetSettings(m.name) }
                        } message: {
                            Text("Position de l'écran, touches et volume reviennent aux valeurs d'origine. Le fichier va à la Corbeille ; sauvegardes et meilleurs scores sont gardés.")
                        }
                    }

                    Text("Touches").font(.headline).padding(.top, 6)
                    KeyGuideView(machine: m)
                    if m.engineKind == .dos || m.engineKind == .scummvm {
                        Button(m.engineKind == .dos ? String(localized: "Touches de ce jeu…") : String(localized: "Options de ScummVM…")) {
                            catalog.openKeyEditor(m.name)
                        }
                        .controlSize(.small)
                        .help(m.engineKind == .dos
                              ? Text("Ouvre l'éditeur de touches de DOSBox ; ce que vous enregistrez ne vaut que pour ce jeu.")
                              : Text("Ouvre les options de ScummVM : onglet « Touches » pour les changer."))
                    } else if m.engineKind == nil || KeyBindings.supported.contains(m.engineKind!) {
                        SettingsLink { Text("Changer les touches…") }
                            .controlSize(.small)
                            .simultaneousGesture(TapGesture().onEnded { UserDefaults.standard.set("keys", forKey: "settingsTab") })
                    }

                    if advanced { ConfigFilesSection(machine: m) }
                }
                .padding()
            }
        } else {
            ContentUnavailableView("Aucun jeu choisi", systemImage: "gamecontroller",
                                   description: Text("Double-cliquez sur un jeu pour le lancer."))
        }
    }

    private func info(_ label: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).textSelection(.enabled)
        }
    }

    /// En-tête d'un jeu PC : l'icône de son moteur.
    private func engineHeader(_ engine: Engine) -> some View {
        HStack(spacing: 14) {
            if let exe = engine.executable, let app = exe.pathComponents.firstIndex(where: { $0.hasSuffix(".app") }) {
                let appPath = NSString.path(withComponents: Array(exe.pathComponents[...app]))
                Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                    .resizable().frame(width: 72, height: 72)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
                    .frame(width: 72, height: 72)
                    .overlay { Image(systemName: engine.symbol).font(.system(size: 30)) }
            }
            VStack(alignment: .leading) {
                Text(engine.title).font(.headline)
                Text("Jeu PC · \(engine.engineName)").foregroundStyle(.secondary)
            }
        }
    }

    private func romText(_ m: Machine) -> String {
        if !m.needsFiles { return String(localized: "Aucune requise") }
        if let r = catalog.auditResult(m.name) { return r.label }
        return catalog.available.contains(m.name) ? String(localized: "Présentes (non vérifiées)") : String(localized: "Absentes")
    }

    private func screenText(_ m: Machine) -> String {
        var parts = [m.screen == "vector" ? String(localized: "Vectoriel") : m.screen == "lcd" ? "LCD" : String(localized: "Matriciel")]
        if m.width > 0 { parts.append("\(m.width) × \(m.height)") }
        if m.refresh > 0 { parts.append(String(format: "%.2f Hz", m.refresh)) }
        parts.append(m.isVertical ? String(localized: "vertical") : String(localized: "horizontal"))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func picture(_ m: Machine) -> some View {
        if let image, imageKey == "\(m.name)/\(kind.rawValue)" {
            Image(nsImage: image)
                .resizable()
                .interpolation(kind == .snap || kind == .title ? .none : .high)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.largeTitle)
                        Text("Pas d'image").font(.caption)
                        if kind == .snap { Text("F12 pendant le jeu en crée une").font(.caption2) }
                    }
                    .foregroundStyle(.secondary)
                }
        }
    }
}

enum PictureKind: String, CaseIterable, Identifiable {
    case snap, title, marquee, flyer, cabinet, cpanel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snap: String(localized: "Capture")
        case .title: String(localized: "Écran titre")
        case .marquee: String(localized: "Fronton")
        case .flyer: String(localized: "Prospectus")
        case .cabinet: String(localized: "Borne d’arcade", comment: "Image : photo du meuble de la borne")
        case .cpanel: String(localized: "Panneau de commande")
        }
    }

    /// Dossiers habituels des packs d'images (progettoSNAPS et compagnie).
    private var folder: String {
        switch self {
        case .snap: "snap"
        case .title: "titles"
        case .marquee: "marquees"
        case .flyer: "flyers"
        case .cabinet: "cabinets"
        case .cpanel: "cpanel"
        }
    }

    /// Cherche nom.png, nom.jpg puis nom/0000.png, et à défaut l'image de
    /// l'original. Les captures F12 (dossier utilisateur) passent avant le pack.
    func imageData(for m: Machine) async -> Data? {
        let dirs = searchDirectories
        return await Task.detached(priority: .userInitiated) {
            Self.find(m, in: dirs)
        }.value
    }

    private var searchDirectories: [URL] {
        var dirs = [Prefs.artworkRoot.appendingPathComponent(folder)]
        if self == .snap { dirs.insert(Prefs.userSnapshots, at: 0) }
        return dirs
    }

    private static func find(_ m: Machine, in dirs: [URL]) -> Data? {
        for name in [m.name, m.cloneOf].compactMap({ $0 }) {
            for dir in dirs {
                let candidates = [
                    dir.appendingPathComponent("\(name).png"),
                    dir.appendingPathComponent("\(name).jpg"),
                    dir.appendingPathComponent(name).appendingPathComponent("0000.png"),
                ]
                for url in candidates {
                    if let data = try? Data(contentsOf: url) { return data }
                }
            }
        }
        return nil
    }
}
