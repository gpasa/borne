import Foundation

/// openQ4 (moteur de Quake 4, Metal, Apple silicon) : téléchargé sur demande
/// depuis sa release officielle, version figée et vérifiée par son empreinte.
/// Borne ne le distribue pas : son code de jeu relève de la licence du SDK de
/// Quake 4, distincte de la GPL.
enum OpenQ4 {
    static let version = "0.13.2"
    static let url = URL(string: "https://github.com/themuffinator/openQ4/releases/download/v0.13.2/openq4-0.13.2-macos-arm64-metal-unsigned.tar.gz")!
    static let sha256 = "6e1d90b7a43e5e8bee2db10fde3d60d9e4912ff5b4eb1b49c2bc2d0304f967c2"
    static let pageURL = URL(string: "https://github.com/themuffinator/openQ4")!
    static let size = "641 Mo"

    static var app: URL {
        Prefs.supportDirectory.appendingPathComponent("Engines/openQ4.app", isDirectory: true)
    }

    static var executable: URL? {
        #if arch(arm64)
        let exe = app.appendingPathComponent("Contents/MacOS/openQ4")
        return FileManager.default.isExecutableFile(atPath: exe.path) ? exe : nil
        #else
        return nil
        #endif
    }

    static var isSupported: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    static func install(progress: @escaping (Double) -> Void) async throws {
        try await VerifiedDownload.installApp(from: url, mirrors: [VerifiedDownload.mirror(url.lastPathComponent)], sha256: sha256, what: "openQ4 \(version)",
                                              appPath: "openq4-0.13.2-macos-arm64-metal-unsigned/openQ4.app",
                                              destination: app, progress: progress)
    }
}
