import Foundation

/// Mise à jour 1.3.1 de Doom 3 (base/pak005 à pak008, d3xp/pak001) : le DVD
/// s'arrête à pak004, et dhewm3 comme Resurrection of Evil veulent la 1.3.1.
/// Borne prend le patch Linux officiel d'id Software (archive auto-extractible,
/// lisible sur Mac), au miroir indiqué par dhewm3.org, après acceptation de sa
/// licence par l'utilisateur ; seuls les fichiers de données sont gardés.
enum Doom3Patch {
    static let url = URL(string: "https://files.holarse-linuxgaming.de/native/Spiele/Doom%203/doom3-linux-1.3.1.1304.x86.run")!
    static let sha256 = "2f90dff20f2d3c0c47f17b3d6d45c4f0e7d27b986bf6084f21b85180cd1e03b4"
    static let pageURL = URL(string: "https://dhewm3.org/#how-to-install")!
    static let size = "21 Mo"
    private static let headerLines = 373
    private static let files = ["base/pak005.pk4", "base/pak006.pk4", "base/pak007.pk4", "base/pak008.pk4", "d3xp/pak001.pk4"]

    static var folder: URL { Prefs.supportDirectory.appendingPathComponent("Doom3Patch", isDirectory: true) }

    static var isInstalled: Bool {
        files.allSatisfy { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path) }
    }

    /// Un dossier de jeu (base ou d3xp) a-t-il besoin du patch ?
    static func isNeeded(base: URL, d3xp: URL?) -> Bool {
        func has(_ dir: URL, _ file: String) -> Bool {
            ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).contains { $0.lowercased() == file }
        }
        return !has(base, "pak008.pk4") || (d3xp.map { !has($0, "pak001.pk4") } ?? false)
    }

    /// Fichiers du patch pour un dossier de jeu ("base" ou "d3xp").
    static func files(for game: String) -> [URL] {
        files.filter { $0.hasPrefix(game + "/") }.map { folder.appendingPathComponent($0) }
    }

    static func install(progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("borne-d3patch-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let run = tmp.appendingPathComponent("patch.run")
        try await VerifiedDownload.fetch(url, sha256: sha256, to: run, what: "la mise à jour 1.3.1 de Doom 3") { progress($0 * 0.9) }
        let x = tmp.appendingPathComponent("Doom3Patch")
        try VerifiedDownload.extractMakeself(run, headerLines: headerLines, members: files.map { "./" + $0 } + ["./License.txt"], into: x)
        guard files.allSatisfy({ fm.fileExists(atPath: x.appendingPathComponent($0).path) }) else {
            throw MAMERunner.Failure(message: "La mise à jour de Doom 3 est incomplète.")
        }
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        try fm.moveItem(at: x, to: folder)
        progress(1)
    }
}
