import Foundation

/// Raze (Duke Nukem 3D, Blood, Shadow Warrior, Redneck Rampage, Exhumed…) :
/// téléchargé sur demande depuis sa release officielle, version figée et
/// vérifiée par son empreinte. Borne ne le distribue pas : une partie de son
/// code relève de la licence Build de Ken Silverman, distincte de la GPL.
/// Binaire universel, signé par ses auteurs, macOS 10.15 et plus.
enum Raze {
    static let version = "1.11.0"
    static let url = URL(string: "https://github.com/ZDoom/Raze/releases/download/1.11.0/raze-macos-1.11.0.zip")!
    static let sha256 = "b7980849a507cfcfeaf8f76298c032bfe4415b2f246f41e3c0c9a6291770c70c"
    static let pageURL = URL(string: "https://raze.zdoom.org")!
    static let size = "32 Mo"

    static var app: URL {
        Prefs.supportDirectory.appendingPathComponent("Engines/Raze.app", isDirectory: true)
    }

    static var executable: URL? {
        let exe = app.appendingPathComponent("Contents/MacOS/raze")
        return FileManager.default.isExecutableFile(atPath: exe.path) ? exe : nil
    }

    static func install(progress: @escaping (Double) -> Void) async throws {
        try await VerifiedDownload.installApp(from: url, sha256: sha256, what: "Raze \(version)",
                                              appPath: "Raze.app", destination: app, progress: progress)
    }
}
