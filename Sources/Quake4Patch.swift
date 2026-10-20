import Foundation

/// Mise à jour 1.4.2 de Quake 4 (pak013 à pak022…) : le DVD d'origine s'arrête
/// à pak012, et openQ4 exige les fichiers de la 1.4.2. Borne prend le patch
/// Linux officiel d'id Software (archive auto-extractible, lisible sur Mac),
/// conservé sur archive.org, après acceptation de sa licence par l'utilisateur.
/// Seuls les fichiers de données sont gardés, rangés dans le dossier utilisateur.
enum Quake4Patch {
    static let url = URL(string: "https://archive.org/download/quake4-linux-1.4.2.x86/quake4-linux-1.4.2.x86.run")!
    static let sha256 = "9203b387b1a4075a1b9ad1eb7be32b49a88141a448d9330d9cbe1f40a145bd6a"
    static let pageURL = URL(string: "https://archive.org/details/quake4-linux-1.4.2.x86")!
    static let size = "288 Mo"
    /// Lignes du script makeself avant l'archive tar.gz.
    private static let headerLines = 375

    static var folder: URL { Prefs.supportDirectory.appendingPathComponent("Quake4Patch", isDirectory: true) }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent("q4base/pak022.pk4").path)
    }

    /// Le dossier d'installation a-t-il besoin du patch (pas de pak022.pk4 dans q4base) ?
    static func isNeeded(base: URL) -> Bool {
        let fm = FileManager.default
        guard let q4base = ((try? fm.contentsOfDirectory(atPath: base.path)) ?? []).first(where: { $0.lowercased() == "q4base" })
        else { return true }
        let items = (try? fm.contentsOfDirectory(atPath: base.appendingPathComponent(q4base).path)) ?? []
        return !items.contains { $0.lowercased() == "pak022.pk4" }
    }

    /// Relie les fichiers du patch dans <dossier utilisateur>/q4base, qu'openQ4
    /// lit en plus de celui du jeu (fs_savepath).
    static func link(into user: URL) throws {
        let fm = FileManager.default
        let src = folder.appendingPathComponent("q4base")
        let dst = user.appendingPathComponent("q4base")
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
        for file in (try? fm.contentsOfDirectory(atPath: src.path)) ?? [] where file.hasSuffix(".pk4") {
            let link = dst.appendingPathComponent(file)
            if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil { try fm.removeItem(at: link) }
            if fm.fileExists(atPath: link.path) { continue }
            try fm.createSymbolicLink(at: link, withDestinationURL: src.appendingPathComponent(file))
        }
    }

    /// Télécharge, vérifie, extrait les données. Rien de partiel ne reste.
    static func install(progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("borne-q4patch-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let run = tmp.appendingPathComponent("patch.run")
        try await VerifiedDownload.fetch(url, sha256: sha256, to: run, what: "la mise à jour 1.4.2 de Quake 4") { progress($0 * 0.9) }

        let x = tmp.appendingPathComponent("x")
        try VerifiedDownload.extractMakeself(run, headerLines: headerLines, members: ["./q4base", "./us", "./License.txt"], into: x)

        // Données seulement : paks communs, paks de la version internationale
        // (« us », hors Allemagne), voix anglaises corrigées. Pas de code de jeu.
        let out = tmp.appendingPathComponent("Quake4Patch/q4base")
        try fm.createDirectory(at: out, withIntermediateDirectories: true)
        for dir in ["q4base", "us/q4base"] {
            let d = x.appendingPathComponent(dir)
            for f in (try? fm.contentsOfDirectory(atPath: d.path)) ?? []
            where f.hasSuffix(".pk4") && !f.hasPrefix("game") {
                let target = out.appendingPathComponent(f)
                if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
                try fm.moveItem(at: d.appendingPathComponent(f), to: target)
            }
        }
        try fm.moveItem(at: x.appendingPathComponent("License.txt"), to: out.deletingLastPathComponent().appendingPathComponent("License.txt"))
        guard fm.fileExists(atPath: out.appendingPathComponent("pak022.pk4").path) else {
            throw MAMERunner.Failure(message: "La mise à jour de Quake 4 est incomplète.")
        }
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        try fm.moveItem(at: out.deletingLastPathComponent(), to: folder)
        progress(1)
    }
}
