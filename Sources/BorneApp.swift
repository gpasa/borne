import SwiftUI

@main
struct BorneApp: App {
    @State private var catalog = Catalog()

    var body: some Scene {
        WindowGroup("Borne") {
            ContentView()
                .environment(catalog)
                .frame(minWidth: 1000, minHeight: 600)
                .task { await catalog.load() }
        }
        .defaultSize(width: 1400, height: 860)
        .commands {
            CommandMenu("Jeux") {
                Button("Lancer") {
                    if let s = catalog.selection { catalog.launch(s) }
                }
                .keyboardShortcut("o")
                .disabled(catalog.selection == nil || catalog.running != nil)

                Button("Favori") {
                    if let s = catalog.selection { catalog.toggleFavorite(s) }
                }
                .keyboardShortcut("d")
                .disabled(catalog.selection == nil)

                Divider()

                Button("Relire les dossiers de jeux") { catalog.rescanAll() }
                    .keyboardShortcut("r")
                Button("Vérifier les ROM") { catalog.verifyROMs() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()

                Button("Installer sur ce Mac…") {
                    if let s = catalog.selection { catalog.proposeInstall([s]) }
                }
                .disabled(catalog.selection.map { !catalog.available.contains($0) || catalog.isLocal($0) } ?? true)
                Button("Installer les favoris sur ce Mac…") {
                    catalog.proposeInstall(Array(catalog.favorites))
                }
                .disabled(catalog.favorites.isEmpty)
                Button("Télécharger Freedoom (Doom libre)…") { catalog.downloadFreedoom() }
                    .disabled(catalog.job != nil || Freedoom.isInstalled)
                Button("Arrêter la tâche en cours") { catalog.cancelJob() }
                    .keyboardShortcut(".")
                    .disabled(catalog.job == nil)

                Divider()

                Button("Recharger la liste de MAME") { Task { await catalog.load(forceRefresh: true) } }
                Button("Ouvrir le dossier ROM") { catalog.revealROMFolder() }
                Button("Afficher les données de jeu") { catalog.revealUserData() }
            }
        }

        Settings {
            SettingsView()
                .environment(catalog)
        }
    }
}
