import Foundation

/// Raze (Duke Nukem 3D, Blood, Shadow Warrior, Redneck Rampage, Exhumed…) :
/// téléchargé sur demande, pas embarqué (une partie de son code relève de la
/// licence Build de Ken Silverman, distincte de la GPL). Build de Borne
/// (scripts/build_zdoom_ports.sh, release_raze.sh) : le Raze officiel replace le
/// pointeur par un événement simulé, et macOS demande alors l'accès
/// d'accessibilité au nom de Borne. Universel, notarisé, macOS 10.15 et plus.
enum Raze {
    static let version = "1.11.0"
    static let url = URL(string: "https://github.com/gpasa/borne/releases/download/raze-1.11.0-borne/Raze-1.11.0-borne.zip")!
    static let sha256 = "5bdcdc0928931dfb9783b165badc5a2785c4f24b16cf24c9afbc5847e0fa5876"
    static let pageURL = URL(string: "https://github.com/gpasa/borne/releases/tag/raze-1.11.0-borne")!
    static let size = "34 Mo"

    static var app: URL {
        Prefs.supportDirectory.appendingPathComponent("Engines/Raze.app", isDirectory: true)
    }

    static var executable: URL? {
        let exe = app.appendingPathComponent("Contents/MacOS/raze")
        // Le Raze officiel (Borne 1.3 et 1.3.1) n'a pas SOURCE.txt : à remplacer.
        let ours = app.appendingPathComponent("Contents/Resources/licenses/SOURCE.txt")
        let fm = FileManager.default
        return fm.isExecutableFile(atPath: exe.path) && fm.fileExists(atPath: ours.path) ? exe : nil
    }

    static func install(progress: @escaping (Double) -> Void) async throws {
        try await VerifiedDownload.installApp(from: url, sha256: sha256, what: "Raze \(version)",
                                              appPath: "Raze.app", destination: app, progress: progress)
    }
}
