import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(Catalog.self) private var catalog

    var body: some View {
        @Bindable var catalog = catalog
        NavigationSplitView {
            FolderList()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            GameTable()
                .navigationSplitViewColumnWidth(min: 480, ideal: 720)
        } detail: {
            GameDetail()
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        }
        .searchable(text: $catalog.search, placement: .toolbar, prompt: "Jeu, nom court, fabricant")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if let s = catalog.selection { catalog.toggleFavorite(s) }
                } label: {
                    Label("Favori", systemImage: isFavorite ? "star.fill" : "star")
                }
                .disabled(catalog.selection == nil)
                Button {
                    if let s = catalog.selection { catalog.launch(s) }
                } label: {
                    Label("Lancer", systemImage: "play.fill")
                }
                .disabled(catalog.selection == nil || catalog.running != nil)
            }
        }
        .alert(catalog.notice?.title ?? "",
               isPresented: Binding(get: { catalog.notice != nil },
                                    set: { if !$0 { catalog.notice = nil } })) {
            Button("OK") {}
        } message: {
            Text(catalog.notice?.message ?? "")
        }
        .alert(catalog.licenseRequest?.title ?? "",
               isPresented: Binding(get: { catalog.licenseRequest != nil },
                                    set: { if !$0 { catalog.licenseRequest = nil } }),
               presenting: catalog.licenseRequest) { r in
            Button(r.readLabel) { NSWorkspace.shared.open(r.url) }
            Button(r.acceptLabel) { r.accept() }
                .keyboardShortcut(.defaultAction)
            Button("Annuler", role: .cancel) {}
        } message: { r in
            Text(r.message)
        }
        .alert(catalog.proposal?.title ?? "",
               isPresented: Binding(get: { catalog.proposal != nil },
                                    set: { if !$0 { catalog.proposal = nil } }),
               presenting: catalog.proposal) { p in
            if p.fits {
                Button("Installer") { catalog.install(p.plan) }
                    .keyboardShortcut(.defaultAction)
            }
            Button("Annuler", role: .cancel) {}
        } message: { p in
            Text(p.message)
        }
    }

    private var isFavorite: Bool {
        catalog.selection.map { catalog.favorites.contains($0) } ?? false
    }
}

// MARK: Dossiers

struct FolderList: View {
    @Environment(Catalog.self) private var catalog
    @State private var chooser: GroupKind?

    var body: some View {
        // Cliquer une ligne « Regrouper par » ouvre son sélecteur au lieu de
        // changer de dossier.
        let selection = Binding<Folder?>(
            get: { catalog.folder },
            set: { new in
                if case .chooser(let k)? = new { chooser = GroupKind(rawValue: k) }
                else if new != catalog.folder { catalog.folder = new }
            })
        List(selection: selection) {
            Section {
                ForEach(Folder.main, id: \.self) { row($0, catalog.counts[$0]) }
            }
            Section("Jeux PC") {
                ForEach(Folder.engines, id: \.self) { row($0, catalog.counts[$0]) }
            }
            Section("Caractéristiques") {
                ForEach(Folder.traits, id: \.self) { row($0, catalog.counts[$0]) }
            }
            Section("Regrouper par") {
                ForEach(GroupKind.allCases) { kind in
                    GroupRow(kind: kind, chooser: $chooser)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ f: Folder, _ count: Int?) -> some View {
        Label {
            HStack {
                Text(f.title).lineLimit(1)
                Spacer()
                if let count { Text("\(count)").foregroundStyle(.secondary).monospacedDigit() }
            }
        } icon: {
            Image(systemName: f.symbol)
        }
        .tag(f)
    }
}

// MARK: Liste

struct GameTable: View {
    @Environment(Catalog.self) private var catalog

    var body: some View {
        @Bindable var catalog = catalog
        GameTableView(catalog: catalog, rows: catalog.displayed,
                      generation: catalog.tableGeneration, selection: catalog.selection)
        .overlay { overlay }
        .safeAreaInset(edge: .top, spacing: 0) { diskBanner }
        .safeAreaInset(edge: .bottom, spacing: 0) { statusBar }
    }

    @ViewBuilder private var overlay: some View {
        switch catalog.phase {
        case .loading(let msg):
            VStack(spacing: 12) {
                ProgressView()
                Text(msg).foregroundStyle(.secondary)
            }
        case .failed(let msg):
            ContentUnavailableView {
                Label("MAME ne répond pas", systemImage: "exclamationmark.triangle")
            } description: {
                Text(msg)
            } actions: {
                SettingsLink { Text("Ouvrir les réglages") }
                Button("Réessayer") { Task { await catalog.load() } }
            }
        default:
            if catalog.displayed.isEmpty && !catalog.machines.isEmpty, case .engine(let e)? = catalog.folder,
               let engine = Engine(rawValue: e) {
                ContentUnavailableView {
                    Label("Aucun jeu \(engine.title)", systemImage: engine.symbol)
                } description: {
                    Text(engineHint(engine))
                } actions: {
                    Button("Ajouter un dossier de jeux…") { addEngineFolder() }
                    if engine == .doom && !Freedoom.isInstalled {
                        Button("Télécharger Freedoom (\(Freedoom.size), libre)") { catalog.downloadFreedoom() }
                            .disabled(catalog.job != nil)
                    }
                }
            } else if catalog.displayed.isEmpty && !catalog.machines.isEmpty {
                if catalog.folder == .available && catalog.search.isEmpty
                    && catalog.missingROMPaths.count == Prefs.romPaths.count {
                    ContentUnavailableView {
                        Label("Disque des jeux introuvable", systemImage: "externaldrive.badge.xmark")
                    } description: {
                        Text("Branchez le disque, puis relisez les dossiers ROM (⌘R).\n"
                             + catalog.missingROMPaths.joined(separator: "\n"))
                    } actions: {
                        Button("Relire") { catalog.rescanAll() }
                        SettingsLink { Text("Réglages") }
                    }
                } else if catalog.folder == .available && catalog.search.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun jeu disponible", systemImage: "folder")
                    } description: {
                        Text("Placez vos ensembles de ROM (.zip) dans le dossier ROM, puis relisez-le (⌘R).")
                    } actions: {
                        Button("Ouvrir le dossier ROM") { catalog.revealROMFolder() }
                        Button("Relire") { catalog.rescanAll() }
                    }
                } else {
                    ContentUnavailableView.search
                }
            }
        }
    }

    /// Disque des jeux pas encore choisi, ou débranché.
    @ViewBuilder private var diskBanner: some View {
        if !catalog.machines.isEmpty && !catalog.missingROMPaths.isEmpty {
            HStack {
                Image(systemName: "externaldrive.badge.questionmark")
                Text(UserDefaults.standard.string(forKey: Prefs.mediaPathKey)?.isEmpty == false
                     ? "Disque des jeux introuvable : branchez-le, puis relisez."
                     : "Où sont vos jeux ? Choisissez le dossier « roms », ou celui qui le contient.")
                Spacer()
                Button("Choisir…") { chooseMediaFolder() }
                Button("Relire") { catalog.rescanAll() }
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.yellow.opacity(0.18))
        } else if let note = catalog.gamesFolderNote {
            HStack {
                Image(systemName: "checkmark.circle").foregroundStyle(.green)
                Text(note).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("OK") { catalog.gamesFolderNote = nil }
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.green.opacity(0.12))
        }
    }

    private func engineHint(_ e: Engine) -> String {
        switch e {
        case .doom: "Borne cherche les fichiers .wad et .pk3 (doom2.wad, heretic.wad…) dans les dossiers que vous lui indiquez, sous-dossiers compris."
        case .quake: "Borne cherche un dossier id1 contenant pak0.pak, et les extensions ou mods à côté de lui."
        case .wolf3d: "Borne cherche les fichiers VSWAP.WL6, VSWAP.SOD… de Wolfenstein 3D et Spear of Destiny."
        case .build: "Borne cherche les fichiers principaux des jeux Build : DUKE3D.GRP, BLOOD.RFF, SW.GRP, REDNECK.GRP, STUFF.DAT (Exhumed), NAM.GRP, WW2GI.GRP. Le moteur Raze se télécharge au premier lancement."
        case .quake4: "Borne cherche le dossier q4base de Quake 4 (pak001.pk4…). Le moteur openQ4 se télécharge au premier lancement."
        case .rtcw: "Borne cherche le dossier de Return to Castle Wolfenstein qui contient pak0.pk3 et sp_pak1.pk3 (Main d'une version GOG ou Steam, par exemple). Seuls les fichiers du jeu d'origine sont chargés."
        case .quake3: "Borne cherche un dossier baseq3 contenant pak0.pk3, et Team Arena (missionpack) où qu'elle soit."
        }
    }

    private func addEngineFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Dossier contenant vos jeux Doom, Quake ou Wolfenstein 3D (lu seulement, sous-dossiers compris)"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { Prefs.addEngineFolder(url.path) }
        catalog.scanEngines()
    }

    private func chooseMediaFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = Prefs.gamesFolderPrompt
        panel.prompt = "Choisir"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        catalog.gamesFolderNote = Prefs.adoptGamesFolder(url)
        catalog.scanROMs()
    }

    private var statusBar: some View {
        HStack {
            Text("\(catalog.displayed.count) jeux affichés · \(catalog.available.count) disponibles sur \(catalog.machines.count)")
            if catalog.refreshing { ProgressView().controlSize(.mini) }
            Spacer()
            if let job = catalog.job {
                Text(job.title)
                if let p = job.progress {
                    ProgressView(value: p).frame(width: 120)
                } else {
                    ProgressView().controlSize(.mini)
                }
                Button("Arrêter") { catalog.cancelJob() }
                    .controlSize(.small)
            } else if let r = catalog.running {
                Text("En cours : \(catalog.machines[r]?.description ?? r)")
            } else if !catalog.version.isEmpty {
                Text("MAME \(catalog.version)\(catalog.hasAudit ? "" : " · ROM non vérifiées")")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }
}
