import Foundation

/// Copie sur le Mac de ce qu'il faut pour lancer un jeu sans le disque des
/// jeux : son set, celui de l'original, du BIOS, des périphériques qui ont
/// des ROM, et ses samples. Les copies vont dans le dossier utilisateur
/// (roms/ et samples/), cherché avant le disque externe au lancement.
struct InstallPlan {
    struct Item {
        let source: URL
        /// Relatif au dossier utilisateur : « roms/sf2.zip ».
        let destination: String
        let bytes: Int64
    }

    var games: [String] = []
    var items: [Item] = []
    /// Fichiers dont chaque jeu a besoin, pour ne supprimer que ce qui ne sert plus.
    var perGame: [String: [String]] = [:]

    var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

enum Installer {
    // MARK: Plan

    static func plan(games: [String], romPaths: [String], samplePaths: [String],
                     userRoot: URL, progress: (Int) -> Void) throws -> InstallPlan {
        var plan = InstallPlan(games: games)
        var queued = Set<String>()
        for (i, game) in games.enumerated() {
            try Task.checkCancellation()
            progress(i)
            let req = try requirements(of: game)
            var files: [String] = []
            func add(_ urls: [URL], folder: String) {
                for url in urls {
                    let dest = "\(folder)/\(url.lastPathComponent)"
                    files.append(dest)
                    guard queued.insert(dest).inserted else { continue }
                    let size = byteCount(url)
                    // Déjà copié et de même taille : rien à refaire.
                    if byteCount(userRoot.appendingPathComponent(dest)) == size { continue }
                    plan.items.append(.init(source: url, destination: dest, bytes: size))
                }
            }
            // Un clone d'un set fusionné n'a pas de fichier à lui : il vit dans
            // le zip de l'original, qui est dans la liste aussi.
            for set in req.sets { add(locate(set, in: romPaths), folder: "roms") }
            for s in req.samples { add(locate(s, in: samplePaths), folder: "samples") }
            plan.perGame[game] = files
        }
        return plan
    }

    /// Parcourt -listxml du jeu (qui inclut ses périphériques), puis de
    /// l'original et du BIOS par la chaîne romof.
    static func requirements(of game: String) throws -> (sets: [String], samples: [String]) {
        var sets: [String] = []
        var samples: [String] = []
        var queue = [game]
        var seen = Set<String>()
        while let name = queue.popLast() {
            guard seen.insert(name).inserted else { continue }
            try Task.checkCancellation()
            let xml = try MAMERunner.run(["-listxml", name])
            let collector = SetCollector()
            let parser = XMLParser(data: Data(xml.utf8))
            parser.delegate = collector
            parser.parse()
            for m in collector.machines {
                if m.needsFiles && !sets.contains(m.name) { sets.append(m.name) }
                if m.hasSamples {
                    let s = m.sampleOf ?? m.name
                    if !samples.contains(s) { samples.append(s) }
                }
                if let r = m.romOf, !seen.contains(r) { queue.append(r) }
            }
        }
        return (sets, samples)
    }

    /// nom.zip, nom.7z et le dossier nom/ (CHD), dans le premier chemin qui en a.
    static func locate(_ name: String, in paths: [String]) -> [URL] {
        let fm = FileManager.default
        for path in paths {
            let base = URL(fileURLWithPath: path)
            var found: [URL] = []
            for ext in ["zip", "7z"] {
                let url = base.appendingPathComponent("\(name).\(ext)")
                if fm.fileExists(atPath: url.path) { found.append(url) }
            }
            var isDir: ObjCBool = false
            let dir = base.appendingPathComponent(name)
            if fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue { found.append(dir) }
            if !found.isEmpty { return found }
        }
        return []
    }

    static func byteCount(_ url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return -1 }
        if !isDir.boolValue {
            return (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        }
        var total: Int64 = 0
        let e = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        while let f = e?.nextObject() as? URL {
            total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    // MARK: Copie

    /// Copie par blocs, interruptible entre deux blocs. Rien de partiel ne
    /// reste : chaque fichier passe par un .part renommé à la fin.
    static func copy(_ plan: InstallPlan, to root: URL, progress: (Int64) -> Void) throws {
        let fm = FileManager.default
        for item in plan.items {
            try Task.checkCancellation()
            let dest = root.appendingPathComponent(item.destination)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.source.path, isDirectory: &isDir)
            if isDir.boolValue {
                let files = fm.enumerator(at: item.source, includingPropertiesForKeys: nil)?
                    .compactMap { $0 as? URL } ?? []
                for file in files {
                    var sub: ObjCBool = false
                    fm.fileExists(atPath: file.path, isDirectory: &sub)
                    if sub.boolValue { continue }
                    let rel = file.path.dropFirst(item.source.path.count + 1)
                    let target = dest.appendingPathComponent(String(rel))
                    if byteCount(target) == byteCount(file) {
                        progress(byteCount(file))
                        continue
                    }
                    try copyFile(file, to: target, progress: progress)
                }
            } else {
                try copyFile(item.source, to: dest, progress: progress)
            }
        }
    }

    private static func copyFile(_ src: URL, to dst: URL, progress: (Int64) -> Void) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmp = dst.appendingPathExtension("part")
        try? fm.removeItem(at: tmp)
        fm.createFile(atPath: tmp.path, contents: nil)
        let input = try FileHandle(forReadingFrom: src)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: tmp)
        do {
            while true {
                try Task.checkCancellation()
                guard let data = try input.read(upToCount: 8 << 20), !data.isEmpty else { break }
                try output.write(contentsOf: data)
                progress(Int64(data.count))
            }
            try output.close()
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.moveItem(at: tmp, to: dst)
        } catch {
            try? output.close()
            try? fm.removeItem(at: tmp)
            throw error
        }
    }

    /// Vérifie que le jeu se lance avec les seules copies locales.
    static func verifyLocal(_ game: String, romRoot: URL) throws -> AuditResult? {
        let out = try MAMERunner.run(["-rompath", romRoot.path, "-verifyroms", game])
        return MAMERunner.parseAudit(out)[game]
    }

    // MARK: Suppression

    /// Retire un jeu du manifeste et efface les fichiers qu'aucun autre jeu
    /// installé n'utilise.
    static func remove(_ game: String, from manifest: [String: [String]],
                       root: URL) -> [String: [String]] {
        var m = manifest
        guard let files = m.removeValue(forKey: game) else { return m }
        let stillUsed = Set(m.values.joined())
        for f in files where !stillUsed.contains(f) {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(f))
        }
        return m
    }
}

/// Lecteur minimal pour -listxml d'un seul jeu.
private final class SetCollector: NSObject, XMLParserDelegate {
    struct Entry {
        var name: String
        var romOf: String?
        var sampleOf: String?
        var needsFiles = false
        var hasSamples = false
    }

    var machines: [Entry] = []

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes a: [String: String] = [:]) {
        switch element {
        case "machine":
            machines.append(Entry(name: a["name"] ?? "", romOf: a["romof"], sampleOf: a["sampleof"]))
        case "rom", "disk":
            if a["status"] != "nodump", !machines.isEmpty { machines[machines.count - 1].needsFiles = true }
        case "sample":
            if !machines.isEmpty { machines[machines.count - 1].hasSamples = true }
        default:
            break
        }
    }
}
