import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(Catalog.self) private var catalog
    @AppStorage(Prefs.mamePathKey) private var mamePath = ""
    @AppStorage(Prefs.mediaPathKey) private var mediaPath = ""
    @AppStorage(Prefs.romPathsKey) private var romPaths = ""
    @AppStorage(Prefs.artworkPathKey) private var artworkPath = ""
    @AppStorage(Prefs.userDataPathKey) private var userDataPath = ""
    @AppStorage(Prefs.windowedKey) private var windowed = true
    @AppStorage(Prefs.extraArgsKey) private var extraArgs = ""
    @AppStorage(Prefs.engineFoldersKey) private var engineFolders = ""
    @AppStorage("vulkanDriver") private var vulkanDriver = "auto"

    var body: some View {
        Form {
            Section("MAME") {
                pathRow("Exécutable", $mamePath, placeholder: Prefs.mameURLPlaceholder, directory: false) {
                    Task { await catalog.load() }
                }
            }

            Section {
                HStack {
                    Text(mediaPath.isEmpty ? "Pas encore choisi" : mediaPath)
                        .lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(mediaPath.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button("Choisir…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.message = Prefs.gamesFolderPrompt
                        if panel.runModal() == .OK, let url = panel.url {
                            catalog.gamesFolderNote = Prefs.adoptGamesFolder(url)
                            catalog.scanROMs()
                        }
                    }
                }
                Text("Le dossier « roms » ou celui qui le contient. Lu seulement, jamais modifié.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Disque des jeux")
            }

            Section("Dossiers ROM") {
                ForEach(Prefs.romPaths, id: \.self) { path in
                    HStack {
                        Image(systemName: FileManager.default.fileExists(atPath: path)
                              ? "folder" : "exclamationmark.triangle")
                        Text(path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        if !romPaths.isEmpty {
                            Button("Retirer", systemImage: "minus.circle") { remove(path) }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Ajouter un dossier…") { addROMFolder() }
            }

            Section("Images") {
                pathRow("Racine", $artworkPath, placeholder: Prefs.mediaRoot.path, directory: true) {}
                Text("Sous-dossiers snap, titles, marquees, flyers, cabinets, cpanel.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Données de jeu") {
                pathRow("Dossier", $userDataPath, placeholder: Prefs.defaultUserDataPath, directory: true) {}
                Text("Sauvegardes, réglages par jeu, scores, captures et enregistrements.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Afficher dans le Finder") { catalog.revealUserData() }
            }

            Section {
                ForEach(Prefs.engineFolders, id: \.self) { path in
                    HStack {
                        Image(systemName: FileManager.default.fileExists(atPath: path) ? "folder" : "exclamationmark.triangle")
                        Text(path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Retirer", systemImage: "minus.circle") {
                            engineFolders = Prefs.engineFolders.filter { $0 != path }.joined(separator: "\n")
                            catalog.scanEngines()
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
                Button("Ajouter un dossier…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = true
                    guard panel.runModal() == .OK else { return }
                    for url in panel.urls { Prefs.addEngineFolder(url.path) }
                    engineFolders = Prefs.engineFolders.joined(separator: "\n")
                    catalog.scanEngines()
                }
                ForEach(Engine.allCases) { engine in
                    EngineRow(engine: engine) { catalog.scanEngines() }
                }
                Picker("Pilote Vulkan de Quake", selection: $vulkanDriver) {
                    Text("Automatique").tag("auto")
                    Text("MoltenVK").tag("moltenvk")
                }
            } header: {
                Text("Jeux PC (Doom, Quake, Wolfenstein 3D)")
            } footer: {
                Text("Dossiers lus seulement, sous-dossiers compris.")
            }

            Section("Lancement") {
                Toggle("Dans une fenêtre", isOn: $windowed)
                TextField("Options en plus", text: $extraArgs, prompt: Text("-bgfx_screen_chains crt-geom"))
            }
        }
        .formStyle(.grouped)
        .frame(width: 600)
        .fixedSize(horizontal: false, vertical: true)
    }

    private struct EngineRow: View {
        let engine: Engine
        let changed: () -> Void
        @AppStorage private var path: String

        init(engine: Engine, changed: @escaping () -> Void) {
            self.engine = engine
            self.changed = changed
            _path = AppStorage(wrappedValue: "", engine.prefKey)
        }

        var body: some View {
            HStack {
                Text("Moteur \(engine.title)")
                Spacer()
                Text(path.isEmpty ? "Intégré (\(engine.engineName))" : (path as NSString).lastPathComponent)
                    .foregroundStyle(.secondary).lineLimit(1)
                Button("Choisir…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.application, .unixExecutable]
                    panel.directoryURL = URL(fileURLWithPath: "/Applications")
                    if panel.runModal() == .OK, let url = panel.url {
                        path = url.path
                        changed()
                    }
                }
                if !path.isEmpty {
                    Button("Intégré") { path = ""; changed() }
                }
            }
        }
    }

    private func pathRow(_ label: String, _ value: Binding<String>, placeholder: String,
                         directory: Bool, changed: @escaping () -> Void) -> some View {
        HStack {
            TextField(label, text: value, prompt: Text(placeholder))
                .onSubmit(changed)
            Button("Choisir…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = !directory
                panel.canChooseDirectories = directory
                if panel.runModal() == .OK, let url = panel.url {
                    value.wrappedValue = url.path
                    changed()
                }
            }
        }
    }

    private func addROMFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        // Tant que la liste est vide, roms/ du disque des jeux est implicite :
        // on le garde en tête quand on en ajoute d'autres.
        var list = Prefs.romPaths
        for url in panel.urls where !list.contains(url.path) { list.append(url.path) }
        romPaths = list.joined(separator: "\n")
        catalog.scanROMs()
    }

    private func remove(_ path: String) {
        romPaths = Prefs.romPaths.filter { $0 != path }.joined(separator: "\n")
        catalog.scanROMs()
    }
}
