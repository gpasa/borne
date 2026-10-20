import CryptoKit
import Foundation

/// Jeux DOS, lancés par DOSBox Staging. Borne les reconnaît à leur exécutable,
/// dans un dossier ou dans une archive (.zip, .rar, .7z). Le disque des jeux
/// reste en lecture seule : une archive est décompressée dans le dossier
/// utilisateur au premier lancement ; un dossier est monté tel quel, avec une
/// surcouche où vont les sauvegardes et réglages du jeu.
enum DOSGames {
    struct Known {
        let title: String
        let year: String
        let maker: String
        /// Commandes DOS, lancées dans le dossier de l'exécutable.
        let run: [String]
        var players = 1

        init(title: String, year: String, maker: String, run: String..., players: Int = 1) {
            self.title = title
            self.year = year
            self.maker = maker
            self.run = run
            self.players = players
        }
    }

    /// Par nom d'exécutable, en minuscules.
    static let known: [String: Known] = [
        "tnfs.exe": .init(title: "The Need for Speed", year: "1995", maker: "Pioneer Productions / Electronic Arts", run: "TNFS SB"),
        "hocus.exe": .init(title: "Hocus Pocus", year: "1994", maker: "Moonlite Software / Apogee", run: "IF NOT EXIST HOCUS.SAV SETUP", "HOCUS"),
        "keen4e.exe": .init(title: "Commander Keen 4: Secret of the Oracle", year: "1991", maker: "id Software / Apogee", run: "KEEN4E"),
        "keen5e.exe": .init(title: "Commander Keen 5: The Armageddon Machine", year: "1991", maker: "id Software / Apogee", run: "KEEN5E"),
        "keen6e.exe": .init(title: "Commander Keen 6: Aliens Ate My Baby Sitter!", year: "1991", maker: "id Software / FormGen", run: "KEEN6E"),
        "bmenace1.exe": .init(title: "Bio Menace 1: Dr. Mangle's Lab", year: "1993", maker: "Apogee", run: "BMENACE1"),
        "bmenace2.exe": .init(title: "Bio Menace 2: Rescue Operation", year: "1993", maker: "Apogee", run: "BMENACE2"),
        "bmenace3.exe": .init(title: "Bio Menace 3: The Final Showdown", year: "1993", maker: "Apogee", run: "BMENACE3"),
        "bash1.exe": .init(title: "Monster Bash 1: Bash the Monsters", year: "1993", maker: "Apogee", run: "BASH1"),
        "bash2.exe": .init(title: "Monster Bash 2: Through the Graveyard", year: "1993", maker: "Apogee", run: "BASH2"),
        "bash3.exe": .init(title: "Monster Bash 3: Dr. Von Frankenbone", year: "1993", maker: "Apogee", run: "BASH3"),
        "bs_fire.exe": .init(title: "Blake Stone: Planet Strike", year: "1994", maker: "JAM Productions / Apogee", run: "PLANET"),
        "catabyss.exe": .init(title: "Catacomb Abyss", year: "1992", maker: "Softdisk / Gamer's Edge", run: "START"),
        "n3d.exe": .init(title: "Nitemare 3D", year: "1994", maker: "Gray Design Associates", run: "N3D"),
        "niteraid.exe": .init(title: "Night Raid", year: "1992", maker: "Argo Games / Software Creations", run: "NITERAID"),
        "stunts.com": .init(title: "Stunts (4D Sports Driving)", year: "1990", maker: "Distinctive Software / Brøderbund", run: "STUNTS", players: 2),
        "sws.exe": .init(title: "Sensible World of Soccer", year: "1994", maker: "Sensible Software", run: "SWS", players: 2),
        "wrms.exe": .init(title: "Worms", year: "1995", maker: "Team17", run: "WORMS", players: 4),
    ]

    /// Ce que le jeu demande au premier lancement.
    static let notes: [String: String] = [
        "hocus": "Au premier lancement, le programme SETUP du jeu demande la carte son : choisissez Sound Blaster (port 220, IRQ 7, DMA 1) et la carte musicale Sound Blaster ou AdLib.",
        "stunts": "Au démarrage, le jeu demande l'affichage et le son : choisissez MCGA/VGA et AdLib ou Sound Blaster.",
    ]

    static let archiveExtensions: Set<String> = ["zip", "rar", "7z"]

    // MARK: Détection

    /// Le jeu d'un exécutable trouvé dans un dossier.
    static func game(folder: URL, exe: String) -> Machine? {
        known[exe.lowercased()].map { machine(exe.lowercased(), $0, source: folder.path, inside: nil) }
    }

    /// Les jeux d'une liste d'archives, d'après leur contenu (mis en cache selon
    /// la taille et la date de chaque archive : seules les nouvelles sont lues).
    static func games(inArchives archives: [URL]) -> [Machine] {
        let fm = FileManager.default
        let cacheURL = root.appendingPathComponent("archives.json")
        var cache = (try? JSONDecoder().decode([String: Listing].self, from: Data(contentsOf: cacheURL))) ?? [:]
        var fresh: [String: Listing] = [:]
        var out: [Machine] = []
        for url in archives {
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int, let date = attrs[.modificationDate] as? Date else { continue }
            var listing = cache[url.path]
            if listing?.size != size || listing?.date != date {
                listing = Listing(size: size, date: date, entries: entries(of: url) ?? [])
            }
            guard let listing else { continue }
            fresh[url.path] = listing
            for entry in listing.entries {
                let parts = entry.split(separator: "/")
                guard let file = parts.last.map(String.init), let k = known[file.lowercased()] else { continue }
                out.append(machine(file.lowercased(), k, source: url.path, inside: parts.dropLast().joined(separator: "/")))
            }
        }
        cache = fresh
        if let data = try? JSONEncoder().encode(cache) {
            try? fm.createDirectory(at: root, withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
        }
        return out
    }

    private struct Listing: Codable {
        let size: Int
        let date: Date
        let entries: [String]
    }

    /// Liste d'une archive par bsdtar (libarchive, livré avec macOS). Nil si elle
    /// est illisible : une RAR « solide », par exemple.
    private static func entries(of archive: URL) -> [String]? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/bsdtar")
        p.arguments = ["-tf", archive.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        let lines = text.split(separator: "\n").map(String.init)
        return p.terminationStatus == 0 || !lines.isEmpty ? lines : nil
    }

    private static func machine(_ exe: String, _ k: Known, source: String, inside: String?) -> Machine {
        var m = Machine(name: "dos:\((exe as NSString).deletingPathExtension)")
        m.description = k.title
        m.year = k.year
        m.manufacturer = k.maker
        m.engine = Engine.dos.rawValue
        m.dataPath = source
        // Dans une archive : le dossier de l'exécutable (vide à la racine).
        m.modArg = inside
        m.status = "good"
        m.emulation = "good"
        m.savestate = true
        m.players = k.players
        m.controls = ["keyboard"]
        m.screen = "raster"
        m.sourcefile = "DOSBox Staging"
        return m
    }

    static func known(for m: Machine) -> Known? {
        let stem = m.name.replacingOccurrences(of: "dos:", with: "")
        return known.first { ($0.key as NSString).deletingPathExtension == stem }?.value
    }

    // MARK: Décompression

    static var root: URL { Prefs.userDataRoot.appendingPathComponent("dos") }

    static func isArchive(_ m: Machine) -> Bool {
        m.dataPath.map { archiveExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) } ?? false
    }

    /// Dossier où une archive est décompressée : un par archive (Monster Bash en
    /// contient trois épisodes), nommé d'après elle et son chemin.
    static func extractedFolder(archive: String) -> URL {
        let name = URL(fileURLWithPath: archive).deletingPathExtension().lastPathComponent
        let hash = SHA256.hash(data: Data(archive.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("archives/\(name)-\(hash)")
    }

    static func isExtracted(_ m: Machine) -> Bool {
        guard let archive = m.dataPath else { return false }
        return FileManager.default.fileExists(atPath: extractedFolder(archive: archive).path)
    }

    /// Décompresse l'archive d'un jeu dans le dossier utilisateur, à côté puis
    /// renommée : une décompression interrompue ne laisse pas de jeu à moitié là.
    static func extract(_ m: Machine) async throws {
        guard let archive = m.dataPath else { return }
        let fm = FileManager.default
        let dest = extractedFolder(archive: archive)
        let tmp = dest.deletingLastPathComponent().appendingPathComponent(".\(dest.lastPathComponent)-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/bsdtar")
        p.arguments = ["-xf", archive, "-C", tmp.path]
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                p.terminationHandler = { _ in c.resume() }
                do { try p.run() } catch { c.resume(throwing: error) }
            }
        } onCancel: { p.terminate() }
        try Task.checkCancellation()
        guard p.terminationStatus == 0 else {
            let text = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw MAMERunner.Failure(message: "L'archive \(URL(fileURLWithPath: archive).lastPathComponent) n'a pas pu être décompressée.\n\(text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        try? fm.removeItem(at: dest)
        try fm.moveItem(at: tmp, to: dest)
    }

    // MARK: Lancement

    /// Arguments de DOSBox Staging : lecteur C: sur le dossier du jeu, puis la
    /// commande du jeu ; DOSBox se ferme quand le jeu se termine.
    static func arguments(for m: Machine, user: URL) throws -> [String] {
        guard let k = known(for: m), let data = m.dataPath else {
            throw MAMERunner.Failure(message: "Borne ne sait pas lancer ce jeu DOS.")
        }
        var mounts: [String]
        if isArchive(m) {
            guard isExtracted(m) else { throw EngineLaunchError.needsExtraction }
            var dir = extractedFolder(archive: data)
            if let inside = m.modArg, !inside.isEmpty { dir.appendPathComponent(inside) }
            mounts = ["mount c \"\(dir.path)\""]
        } else {
            // Dossier sur le disque des jeux : les écritures vont dans la surcouche.
            let overlay = root.appendingPathComponent("overlays/\(m.name.replacingOccurrences(of: "dos:", with: ""))")
            try FileManager.default.createDirectory(at: overlay, withIntermediateDirectories: true)
            mounts = ["mount c \"\(data)\"", "mount -t overlay c \"\(overlay.path)\""]
        }
        let shots = user.appendingPathComponent("shots")
        try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
        var args = ["--noprimaryconf", "--nolocalconf",
                    "--set", "startup_verbosity=quiet",
                    "--set", "capture_dir=\(shots.path)"]
        if !Prefs.windowed { args.append("--fullscreen") }
        for c in mounts + ["c:"] + k.run + ["exit"] { args += ["-c", c] }
        return args
    }
}
