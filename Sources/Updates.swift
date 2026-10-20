import Sparkle
import SwiftUI

/// Mises à jour par Sparkle : Borne lit chaque jour le flux de la dernière release
/// GitHub (un par architecture), vérifie la signature EdDSA de la nouvelle version,
/// la remplace et se relance.
@MainActor
final class Updates: ObservableObject {
    static let shared = Updates()
    private let delegate = UpdaterDelegate()
    let controller: SPUStandardUpdaterController
    @Published private(set) var canCheck = false
    private var observation: NSKeyValueObservation?

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: delegate, userDriverDelegate: nil)
        // Tests : -checkUpdatesNow YES vérifie tout de suite, en arrière-plan.
        if UserDefaults.standard.bool(forKey: "checkUpdatesNow") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [controller] in
                controller.updater.checkForUpdatesInBackground()
            }
        }
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor in self?.canCheck = updater.canCheckForUpdates }
        }
    }

    var updater: SPUUpdater { controller.updater }

    func check() { controller.checkForUpdates(nil) }
}

/// Tests : -testFeedURL http://127.0.0.1:… remplace le flux de la release.
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: "testFeedURL")
    }
}

/// « Rechercher les mises à jour… », dans le menu Borne.
struct CheckForUpdatesCommand: View {
    @ObservedObject private var updates = Updates.shared

    var body: some View {
        Button("Rechercher les mises à jour…") { updates.check() }
            .disabled(!updates.canCheck)
    }
}

/// Réglages → Général : recherche et installation automatiques.
struct UpdateSettings: View {
    @State private var automaticChecks = Updates.shared.updater.automaticallyChecksForUpdates
    @State private var automaticInstall = Updates.shared.updater.automaticallyDownloadsUpdates

    var body: some View {
        Section {
            Toggle("Rechercher les mises à jour automatiquement", isOn: $automaticChecks)
                .onChange(of: automaticChecks) { _, v in Updates.shared.updater.automaticallyChecksForUpdates = v }
            Toggle("Les installer automatiquement", isOn: $automaticInstall)
                .disabled(!automaticChecks)
                .onChange(of: automaticInstall) { _, v in Updates.shared.updater.automaticallyDownloadsUpdates = v }
            HStack {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                    .foregroundStyle(.secondary)
                Spacer()
                CheckForUpdatesCommand()
            }
        } header: {
            Text("Mises à jour")
        } footer: {
            Text("Borne vérifie chaque jour s'il existe une nouvelle version sur GitHub. Chaque mise à jour est signée : une version qui ne viendrait pas de Borne est refusée.")
        }
    }
}
