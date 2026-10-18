import CryptoKit
import Foundation

/// Freedoom, un Doom entièrement libre (BSD), téléchargé sur demande depuis
/// la release officielle et vérifié par son empreinte publiée.
enum Freedoom {
    static let version = "0.13.0"
    static let url = URL(string: "https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip")!
    /// SHA-256 publié dans freedoom-0.13.0-CHECKSUM.
    static let sha256 = "3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59"
    static let size = "23 Mo"

    static var folder: URL { Prefs.supportDirectory.appendingPathComponent("Freedoom", isDirectory: true) }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent("freedoom2.wad").path)
    }

    /// Télécharge, vérifie et décompresse. Interruptible ; rien de partiel ne reste.
    static func install(progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        let total = max(1, response.expectedContentLength)
        let tmp = fm.temporaryDirectory.appendingPathComponent("borne-freedoom-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let zip = tmp.appendingPathComponent("freedoom.zip")
        fm.createFile(atPath: zip.path, contents: nil)
        let out = try FileHandle(forWritingTo: zip)
        var hasher = SHA256()
        var buffer = Data()
        var done: Int64 = 0
        do {
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= 1 << 16 {
                    try Task.checkCancellation()
                    hasher.update(data: buffer)
                    try out.write(contentsOf: buffer)
                    done += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    progress(Double(done) / Double(total))
                }
            }
            hasher.update(data: buffer)
            try out.write(contentsOf: buffer)
            try out.close()
        } catch {
            try? out.close()
            throw error
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else {
            throw MAMERunner.Failure(message: "Le fichier téléchargé ne correspond pas à l'empreinte publiée par Freedoom ; rien n'a été installé.")
        }
        // Décompression avec ditto, puis seuls les WAD et les textes de licence sont gardés.
        let unpacked = tmp.appendingPathComponent("x")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-x", "-k", zip.path, unpacked.path]
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw MAMERunner.Failure(message: "Décompression de Freedoom impossible.") }
        let staged = tmp.appendingPathComponent("Freedoom")
        try fm.createDirectory(at: staged, withIntermediateDirectories: true)
        let keep: Set<String> = ["freedoom1.wad", "freedoom2.wad", "COPYING.txt", "CREDITS.txt"]
        let e = fm.enumerator(at: unpacked, includingPropertiesForKeys: nil)
        while let f = e?.nextObject() as? URL {
            guard keep.contains(f.lastPathComponent) else { continue }
            try fm.copyItem(at: f, to: staged.appendingPathComponent(f.lastPathComponent))
        }
        guard fm.fileExists(atPath: staged.appendingPathComponent("freedoom2.wad").path) else {
            throw MAMERunner.Failure(message: "Les WAD de Freedoom sont absents de l'archive.")
        }
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        try fm.moveItem(at: staged, to: folder)
    }
}
