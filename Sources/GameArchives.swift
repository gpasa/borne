import CryptoKit
import Foundation

/// Archives de jeux (.zip, .rar, .7z) et images de disque (.iso), pour les jeux
/// DOS et ScummVM. Le disque des jeux reste en lecture seule : Borne lit leur
/// contenu, puis les décompresse dans le dossier utilisateur au premier lancement.
enum GameArchives {
    static let extensions: Set<String> = ["zip", "rar", "7z", "iso"]

    static var root: URL { Prefs.userDataRoot.appendingPathComponent("archives") }

    static func isArchive(_ path: String?) -> Bool {
        path.map { extensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) } ?? false
    }

    // MARK: Contenu

    private struct Listing: Codable {
        let size: Int
        let date: Date
        let entries: [String]
    }

    /// Contenu de chaque archive (chemins relatifs), mis en cache selon sa taille
    /// et sa date : seules les nouvelles sont relues.
    static func listings(_ archives: [URL]) -> [(url: URL, entries: [String])] {
        let fm = FileManager.default
        let cacheURL = root.appendingPathComponent("index-2.json")
        let cache = (try? JSONDecoder().decode([String: Listing].self, from: Data(contentsOf: cacheURL))) ?? [:]
        var fresh: [String: Listing] = [:]
        var out: [(URL, [String])] = []
        for url in archives {
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int, let date = attrs[.modificationDate] as? Date else { continue }
            var listing = cache[url.path]
            if listing?.size != size || listing?.date != date {
                listing = Listing(size: size, date: date, entries: entries(of: url) ?? [])
            }
            guard let listing else { continue }
            fresh[url.path] = listing
            out.append((url, listing.entries))
        }
        if let data = try? JSONEncoder().encode(fresh) {
            try? fm.createDirectory(at: root, withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
        }
        return out
    }

    /// Archives par bsdtar (libarchive, livré avec macOS) ; images ISO montées en
    /// lecture seule par hdiutil, le temps de les parcourir. Nil si illisible
    /// (une RAR « solide », par exemple).
    private static func entries(of archive: URL) -> [String]? {
        if archive.pathExtension.lowercased() == "iso" {
            return try? withMountedImage(archive) { mount in
                // Chemins relatifs par l'énumérateur lui-même : /var/folders est un
                // lien vers /private/var, et les chemins absolus diffèrent.
                var out: [String] = []
                let e = FileManager.default.enumerator(atPath: mount.path)
                while let rel = e?.nextObject() as? String {
                    if !rel.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { out.append(rel) }
                }
                return out
            }
        }
        let (status, text) = run("/usr/bin/bsdtar", ["-tf", archive.path])
        let lines = text.split(separator: "\n").map(String.init)
        return status == 0 || !lines.isEmpty ? lines : nil
    }

    // MARK: Décompression

    /// Dossier où une archive est décompressée : un par archive (Monster Bash en
    /// contient trois épisodes, la collection LucasArts sept jeux), nommé
    /// d'après elle et son chemin.
    static func extractedFolder(archive: String) -> URL {
        let name = URL(fileURLWithPath: archive).deletingPathExtension().lastPathComponent
        let hash = SHA256.hash(data: Data(archive.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("\(name)-\(hash)")
    }

    static func isExtracted(_ archive: String?) -> Bool {
        guard let archive else { return false }
        return FileManager.default.fileExists(atPath: extractedFolder(archive: archive).path)
    }

    /// Dossier du jeu une fois décompressé (sous-dossier `inside` éventuel).
    static func gameFolder(archive: String, inside: String?) -> URL {
        var dir = extractedFolder(archive: archive)
        if let inside, !inside.isEmpty { dir.appendPathComponent(inside) }
        return dir
    }

    /// Décompresse dans le dossier utilisateur, à côté puis renommé : une
    /// décompression interrompue ne laisse pas de jeu à moitié là.
    static func extract(_ archive: String) async throws {
        let fm = FileManager.default
        let dest = extractedFolder(archive: archive)
        let tmp = dest.deletingLastPathComponent().appendingPathComponent(".\(dest.lastPathComponent)-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let url = URL(fileURLWithPath: archive)
        try await Task.detached {
            if url.pathExtension.lowercased() == "iso" {
                try withMountedImage(url) { mount in
                    let (status, text) = run("/usr/bin/ditto", [mount.path, tmp.path])
                    guard status == 0 else { throw failure(url, text) }
                }
            } else {
                let (status, text) = run("/usr/bin/bsdtar", ["-xf", url.path, "-C", tmp.path])
                guard status == 0 else { throw failure(url, text) }
            }
        }.value
        try Task.checkCancellation()
        // Fichiers d'un CD : en lecture seule, que le jeu ne pourrait pas modifier.
        _ = run("/bin/chmod", ["-R", "u+w", tmp.path])
        try? fm.removeItem(at: dest)
        try fm.moveItem(at: tmp, to: dest)
    }

    private static func failure(_ url: URL, _ text: String) -> Error {
        MAMERunner.Failure(message: "\(url.lastPathComponent) n'a pas pu être décompressé.\n\(text.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    // MARK: Outils

    private static func withMountedImage<T>(_ image: URL, _ body: (URL) throws -> T) throws -> T {
        let mount = FileManager.default.temporaryDirectory.appendingPathComponent("borne-iso-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let (status, text) = run("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-noautoopen", "-mountpoint", mount.path, image.path])
        guard status == 0 else { throw failure(image, text) }
        defer { _ = run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
        return try body(mount)
    }

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = out
        guard (try? p.run()) != nil else { return (-1, "") }
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        return (p.terminationStatus, text)
    }
}
