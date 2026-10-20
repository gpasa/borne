import CryptoKit
import Foundation

/// Téléchargement par blocs vers un fichier, empreinte SHA-256 calculée au fil
/// de l'eau et vérifiée à la fin. Interruptible ; rien ne reste en cas d'échec.
enum VerifiedDownload {
    /// Copie d'un module redistribuable dans la release « modules » du dépôt de Borne.
    static func mirror(_ name: String) -> URL {
        URL(string: "https://github.com/gpasa/borne/releases/download/modules/\(name)")!
    }

    /// Source d'origine d'abord ; en cas d'échec (site disparu, fichier changé),
    /// les copies de secours, vérifiées par la même empreinte.
    static func fetch(_ url: URL, mirrors: [URL] = [], sha256: String, to file: URL, what: String,
                      progress: @escaping (Double) -> Void) async throws {
        var lastError: Error?
        for source in [url] + mirrors {
            do {
                try await fetchOne(source, sha256: sha256, to: file, what: what, progress: progress)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError ?? MAMERunner.Failure(message: "Téléchargement de \(what) impossible.")
    }

    private static func fetchOne(_ url: URL, sha256: String, to file: URL, what: String,
                                 progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw MAMERunner.Failure(message: "\(url.host() ?? "Le serveur") répond \(http.statusCode).")
        }
        let total = max(1, response.expectedContentLength)
        fm.createFile(atPath: file.path, contents: nil)
        let out = try FileHandle(forWritingTo: file)
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
                    progress(Double(done) / Double(total))
                }
            }
            hasher.update(data: buffer)
            try out.write(contentsOf: buffer)
            try out.close()
        } catch {
            try? out.close()
            try? fm.removeItem(at: file)
            throw error
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else {
            try? fm.removeItem(at: file)
            throw MAMERunner.Failure(message: "Le fichier téléchargé ne correspond pas à \(what) ; rien n'a été installé.")
        }
    }

    /// Extrait une archive (tar.gz par tar, zip par ditto) dans un dossier.
    static func extract(_ archive: URL, into dir: URL) throws {
        let p = Process()
        if archive.pathExtension == "zip" {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            p.arguments = ["-x", "-k", archive.path, dir.path]
        } else {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            p.arguments = ["-xzf", archive.path, "-C", dir.path]
        }
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw MAMERunner.Failure(message: "L'archive téléchargée n'a pas pu être ouverte.")
        }
    }

    /// Extrait des membres d'une archive makeself (patchs Linux d'id Software :
    /// script shell de `headerLines` lignes suivi d'un tar.gz).
    static func extractMakeself(_ run: URL, headerLines: Int, members: [String], into dir: URL) throws {
        let handle = try FileHandle(forReadingFrom: run)
        let head = try handle.read(upToCount: 64 << 10) ?? Data()
        try handle.close()
        var newlines = 0
        guard let end = head.firstIndex(where: { byte in
            if byte == 0x0A { newlines += 1 }
            return newlines == headerLines
        }) else { throw MAMERunner.Failure(message: "L'archive téléchargée est illisible.") }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "a=$1 r=$2 d=$3; shift 3; tail -c +\"$a\" \"$r\" | /usr/bin/tar -xzf - -C \"$d\" \"$@\"",
                       "sh", String(end + 2), run.path, dir.path] + members
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw MAMERunner.Failure(message: "L'archive téléchargée n'a pas pu être extraite.") }
    }

    /// Télécharge, vérifie, extrait et installe l'app `appName` à `destination`.
    static func installApp(from url: URL, mirrors: [URL] = [], sha256: String, what: String, appPath: String,
                           destination: URL, progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("borne-dl-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let archive = tmp.appendingPathComponent(url.lastPathComponent)
        try await fetch(url, mirrors: mirrors, sha256: sha256, to: archive, what: what) { progress($0 * 0.9) }
        try extract(archive, into: tmp)
        let extracted = tmp.appendingPathComponent(appPath)
        guard fm.fileExists(atPath: extracted.path) else {
            throw MAMERunner.Failure(message: "L'archive de \(what) est incomplète.")
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: extracted, to: destination)
        progress(1)
    }
}
