import Foundation

/// Patch 1.32 de Quake III Arena (fichiers pak1–8 de baseq3, pak1–3 de Team
/// Arena), indispensable aux moteurs modernes avec un CD d'origine. Publié par
/// id Software sous la licence de la démo de Quake III : l'utilisateur
/// l'accepte dans Borne avant le téléchargement, depuis ioquake3.
enum Quake3Patch {
    static let url = URL(string: "https://files.ioquake3.org/quake3-latest-pk3s.zip")!
    static let sha256 = "95a811825a43260b2c52af97ef6f2c26fcc16d0032b3a132d6c4b20457a10ced"
    /// Page où lire la licence d'id Software, telle qu'ioquake3 la présente.
    static let licenseURL = URL(string: "https://ioquake3.org/extras/patch-data/")!
    static let size = "27 Mo"

    static var folder: URL { Prefs.supportDirectory.appendingPathComponent("Quake3Patch", isDirectory: true) }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent("baseq3/pak8.pk3").path)
    }

    /// Le dossier de base a-t-il besoin du patch (pas de pak8.pk3 dans baseq3) ?
    static func isNeeded(base: URL) -> Bool {
        let baseq3 = ((try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? [])
            .first { $0.lowercased() == "baseq3" }
        guard let baseq3 else { return true }
        let items = (try? FileManager.default.contentsOfDirectory(atPath: base.appendingPathComponent(baseq3).path)) ?? []
        return !items.contains { $0.lowercased() == "pak8.pk3" }
    }

    /// Relie les fichiers du patch dans le dossier d'écriture de Quake III, où
    /// le moteur les cherche aussi (fs_homepath).
    static func link(into user: URL) throws {
        let fm = FileManager.default
        for game in ["baseq3", "missionpack"] {
            let src = folder.appendingPathComponent(game)
            let dst = user.appendingPathComponent(game)
            try fm.createDirectory(at: dst, withIntermediateDirectories: true)
            for file in (try? fm.contentsOfDirectory(atPath: src.path)) ?? [] where file.hasSuffix(".pk3") {
                let link = dst.appendingPathComponent(file)
                if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil { try fm.removeItem(at: link) }
                if fm.fileExists(atPath: link.path) { continue }
                try fm.createSymbolicLink(at: link, withDestinationURL: src.appendingPathComponent(file))
            }
        }
    }

    /// Télécharge, vérifie l'empreinte et range les fichiers. Rien de partiel ne reste.
    static func install(progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("borne-q3patch-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let zip = tmp.appendingPathComponent("patch.zip")
        try await VerifiedDownload.fetch(url, mirrors: [VerifiedDownload.mirror(url.lastPathComponent)], sha256: sha256,
                                         to: zip, what: "le patch 1.32 de Quake III", progress: progress)
        let unpacked = tmp.appendingPathComponent("x")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-x", "-k", zip.path, unpacked.path]
        try p.run()
        p.waitUntilExit()
        let root = unpacked.appendingPathComponent("quake3-latest-pk3s")
        guard p.terminationStatus == 0, fm.fileExists(atPath: root.appendingPathComponent("baseq3/pak8.pk3").path) else {
            throw MAMERunner.Failure(message: "Le patch téléchargé est incomplet.")
        }
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        try fm.moveItem(at: root, to: folder)
    }
}
