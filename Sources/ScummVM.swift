import Foundation

/// ScummVM : jeux d'aventure (LucasArts, Revolution…). Téléchargé sur demande
/// depuis scummvm.org, version figée et vérifiée par son empreinte : l'app est
/// signée et notarisée par l'équipe de ScummVM.
enum ScummVM {
    static let version = "2026.4.0"
    static let url = URL(string: "https://downloads.scummvm.org/frs/scummvm/2026.4.0/scummvm-2026.4.0-macosx.dmg")!
    static let sha256 = "5614527fa57ffce14773c69923b96eeb7b1b135bcd96bfe74640ca341cad4598"
    static let pageURL = URL(string: "https://www.scummvm.org")!
    static let size = String(localized: "169 Mo")

    static var app: URL {
        Prefs.supportDirectory.appendingPathComponent("Engines/ScummVM.app", isDirectory: true)
    }

    static var executable: URL? {
        let exe = app.appendingPathComponent("Contents/MacOS/scummvm")
        return FileManager.default.isExecutableFile(atPath: exe.path) ? exe : nil
    }

    static func install(progress: @escaping (Double) -> Void) async throws {
        try await VerifiedDownload.installApp(from: url, sha256: sha256, what: "ScummVM \(version)",
                                              appPath: "ScummVM.app", destination: app, progress: progress)
    }

    // MARK: Jeux

    struct Known {
        let title: String
        let year: String
        let maker: String
    }

    /// Par fichier caractéristique, en minuscules. ScummVM reconnaît lui-même la
    /// version exacte (--auto-detect) ; ce fichier sert à trouver le jeu.
    static let known: [String: Known] = [
        "monkey.000": .init(title: "The Secret of Monkey Island", year: "1990", maker: "Lucasfilm Games"),
        "monkey1.000": .init(title: "The Secret of Monkey Island", year: "1990", maker: "Lucasfilm Games"),
        "monkey2.000": .init(title: "Monkey Island 2: LeChuck's Revenge", year: "1991", maker: "LucasArts"),
        "atlantis.000": .init(title: "Indiana Jones and the Fate of Atlantis", year: "1992", maker: "LucasArts"),
        "tentacle.000": .init(title: "Day of the Tentacle", year: "1993", maker: "LucasArts"),
        "samnmax.000": .init(title: "Sam & Max Hit the Road", year: "1993", maker: "LucasArts"),
        "ft.la0": .init(title: "Full Throttle", year: "1995", maker: "LucasArts"),
        "dig.la0": .init(title: "The Dig", year: "1995", maker: "LucasArts"),
        "comi.la0": .init(title: "The Curse of Monkey Island", year: "1997", maker: "LucasArts"),
        "sky.dnr": .init(title: "Beneath a Steel Sky", year: "1994", maker: "Revolution Software"),
        "queen.1": .init(title: "Flight of the Amazon Queen", year: "1995", maker: "Interactive Binary Illusions"),
        "queen.1c": .init(title: "Flight of the Amazon Queen", year: "1995", maker: "Interactive Binary Illusions"),
    ]

    /// Jeux SCUMM plus anciens (Maniac Mansion, Zak McKracken, Indiana Jones 3,
    /// Loom) : leurs fichiers 00.LFL ne disent pas lequel ; le dossier le dit.
    static let lflFolders: [String: Known] = [
        "maniac": .init(title: "Maniac Mansion", year: "1987", maker: "Lucasfilm Games"),
        "indiana jones 3": .init(title: "Indiana Jones and the Last Crusade", year: "1989", maker: "Lucasfilm Games"),
        "indy3": .init(title: "Indiana Jones and the Last Crusade", year: "1989", maker: "Lucasfilm Games"),
        "loom": .init(title: "Loom", year: "1990", maker: "Lucasfilm Games"),
        "zak": .init(title: "Zak McKracken and the Alien Mindbenders", year: "1988", maker: "Lucasfilm Games"),
    ]

    /// Le jeu désigné par un fichier, dans le dossier `folder` (chemin du disque
    /// ou de l'archive).
    static func known(file: String, folder: String) -> (key: String, game: Known)? {
        let lower = file.lowercased()
        if let k = known[lower] { return ((lower as NSString).deletingPathExtension, k) }
        guard lower == "00.lfl" else { return nil }
        let dir = (folder as NSString).lastPathComponent
        let k = lflFolders[dir.lowercased()] ?? Known(title: dir, year: "", maker: "Lucasfilm Games")
        return ("lfl-" + dir.lowercased().replacingOccurrences(of: " ", with: "-"), k)
    }

    static func game(folder: URL, file: String) -> Machine? {
        known(file: file, folder: folder.path).map { machine($0.key, $0.game, source: folder.path, inside: nil) }
    }

    static func games(in listings: [(url: URL, entries: [String])]) -> [Machine] {
        var out: [Machine] = []
        for (url, entries) in listings {
            for entry in entries {
                let parts = entry.split(separator: "/").map(String.init)
                guard let file = parts.last else { continue }
                let inside = parts.dropLast().joined(separator: "/")
                guard let (key, k) = known(file: file, folder: inside.isEmpty ? url.deletingPathExtension().lastPathComponent : inside) else { continue }
                out.append(machine(key, k, source: url.path, inside: inside))
            }
        }
        return out
    }

    private static func machine(_ key: String, _ k: Known, source: String, inside: String?) -> Machine {
        var m = Machine(name: "scummvm:\(key)")
        m.description = k.title
        m.year = k.year
        m.manufacturer = k.maker
        m.engine = Engine.scummvm.rawValue
        m.dataPath = source
        m.modArg = inside
        m.status = "good"
        m.emulation = "good"
        m.savestate = true
        m.players = 1
        m.controls = ["mouse"]
        m.screen = "raster"
        m.sourcefile = "ScummVM"
        return m
    }

    // MARK: Lancement

    /// ScummVM lit le dossier du jeu sans y écrire : réglages et sauvegardes
    /// vont dans le dossier utilisateur.
    static func arguments(for m: Machine, user: URL) throws -> [String] {
        guard let data = m.dataPath else { throw MAMERunner.Failure(message: String(localized: "Fichiers du jeu introuvables.")) }
        let dir: URL
        if GameArchives.isArchive(data) {
            guard GameArchives.isExtracted(data) else { throw EngineLaunchError.needsExtraction }
            dir = GameArchives.gameFolder(archive: data, inside: m.modArg)
        } else {
            dir = URL(fileURLWithPath: data)
        }
        let fm = FileManager.default
        let saves = user.appendingPathComponent("saves/\(m.name.replacingOccurrences(of: "scummvm:", with: ""))")
        let shots = user.appendingPathComponent("shots")
        try fm.createDirectory(at: saves, withIntermediateDirectories: true)
        try fm.createDirectory(at: shots, withIntermediateDirectories: true)
        // Premier lancement : pas de question sur les mises à jour de ScummVM, dont
        // Borne fixe la version ; elle cacherait le jeu derrière le lanceur.
        let ini = user.appendingPathComponent("scummvm.ini")
        if !fm.fileExists(atPath: ini.path) {
            try "[scummvm]\nupdates_check=0\n".write(to: ini, atomically: true, encoding: .utf8)
        }
        return ["--config=\(ini.path)",
                "--savepath=\(saves.path)", "--screenshotpath=\(shots.path)",
                Prefs.windowed ? "--no-fullscreen" : "--fullscreen",
                "--path=\(dir.path)", "--auto-detect"]
    }
}
