import Foundation

/// Freedoom, un Doom entièrement libre (BSD), téléchargé sur demande depuis
/// la release officielle et vérifié par son empreinte publiée.
enum Freedoom {
    static let version = "0.13.0"
    static let url = URL(string: "https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip")!
    /// SHA-256 publié dans freedoom-0.13.0-CHECKSUM.
    static let sha256 = "3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59"
    static let size = String(localized: "23 Mo")

    static var folder: URL { Prefs.supportDirectory.appendingPathComponent("Freedoom", isDirectory: true) }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent("freedoom2.wad").path)
    }

    /// Télécharge, vérifie et décompresse. Interruptible ; rien de partiel ne reste.
    static func install(progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("borne-freedoom-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let zip = tmp.appendingPathComponent("freedoom.zip")
        try await VerifiedDownload.fetch(url, mirrors: [VerifiedDownload.mirror(url.lastPathComponent)], sha256: sha256,
                                         to: zip, what: "Freedoom \(version)", progress: progress)
        // Décompression avec ditto, puis seuls les WAD et les textes de licence sont gardés.
        let unpacked = tmp.appendingPathComponent("x")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-x", "-k", zip.path, unpacked.path]
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw MAMERunner.Failure(message: String(localized: "Décompression de Freedoom impossible.")) }
        let staged = tmp.appendingPathComponent("Freedoom")
        try fm.createDirectory(at: staged, withIntermediateDirectories: true)
        let keep: Set<String> = ["freedoom1.wad", "freedoom2.wad", "COPYING.txt", "CREDITS.txt"]
        let e = fm.enumerator(at: unpacked, includingPropertiesForKeys: nil)
        while let f = e?.nextObject() as? URL {
            guard keep.contains(f.lastPathComponent) else { continue }
            try fm.copyItem(at: f, to: staged.appendingPathComponent(f.lastPathComponent))
        }
        guard fm.fileExists(atPath: staged.appendingPathComponent("freedoom2.wad").path) else {
            throw MAMERunner.Failure(message: String(localized: "Les WAD de Freedoom sont absents de l'archive."))
        }
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        try fm.moveItem(at: staged, to: folder)
    }
}
