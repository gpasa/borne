import CryptoKit
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

    static var folder: URL { Prefs.supportDirectory.appendingPathComponent("Engines", isDirectory: true) }
    static var app: URL { folder.appendingPathComponent("openQ4.app") }

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

    /// Télécharge (641 Mo), vérifie l'empreinte, extrait openQ4.app. Interruptible.
    static func install(progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("borne-openq4-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        // Téléchargement par blocs vers un fichier, empreinte calculée au fil de l'eau.
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        let total = max(1, response.expectedContentLength)
        let archive = tmp.appendingPathComponent("openq4.tar.gz")
        fm.createFile(atPath: archive.path, contents: nil)
        let out = try FileHandle(forWritingTo: archive)
        var hasher = SHA256()
        var buffer = Data()
        var done: Int64 = 0
        do {
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= 1 << 20 {
                    try Task.checkCancellation()
                    hasher.update(data: buffer)
                    try out.write(contentsOf: buffer)
                    done += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    progress(Double(done) / Double(total) * 0.9)
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
            throw MAMERunner.Failure(message: "Le fichier téléchargé ne correspond pas à openQ4 \(version) ; rien n'a été installé.")
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-xzf", archive.path, "-C", tmp.path]
        try p.run()
        p.waitUntilExit()
        let extracted = tmp.appendingPathComponent("openq4-0.13.2-macos-arm64-metal-unsigned/openQ4.app")
        guard p.terminationStatus == 0, fm.fileExists(atPath: extracted.path) else {
            throw MAMERunner.Failure(message: "L'archive d'openQ4 est incomplète.")
        }
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if fm.fileExists(atPath: app.path) { try fm.removeItem(at: app) }
        try fm.moveItem(at: extracted, to: app)
        progress(1)
    }
}
