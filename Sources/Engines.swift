import AppKit
import Foundation

/// Moteurs de jeux PC embarqués : Doom (UZDoom, ou GZDoom sur Intel),
/// Quake (vkQuake) et Wolfenstein 3D (ECWolf). Les données des jeux restent
/// où elles sont, en lecture seule ; chaque moteur écrit dans
/// <dossier utilisateur>/engines/<moteur>.
enum Engine: String, CaseIterable, Codable, Identifiable {
    case doom, quake, wolf3d, quake3, rtcw, quake4, build, doom3, quake2, dos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doom: "Doom"
        case .quake: "Quake"
        case .wolf3d: "Wolfenstein 3D"
        case .quake3: "Quake III Arena"
        case .rtcw: "Return to Castle Wolfenstein"
        case .quake4: "Quake 4"
        case .doom3: "Doom 3"
        case .quake2: "Quake II"
        case .build: "Duke Nukem 3D, Blood…"
        case .dos: "Jeux DOS"
        }
    }

    var symbol: String {
        switch self {
        case .doom: "flame"
        case .quake: "bolt"
        case .wolf3d: "shield.lefthalf.filled"
        case .quake3: "scope"
        case .rtcw: "building.columns"
        case .quake4: "hexagon"
        case .doom3: "moon"
        case .quake2: "triangle"
        case .build: "sunglasses"
        case .dos: "pc"
        }
    }

    // MARK: Exécutables

    /// Moteur embarqué : app dans Resources/Engines, ou binaire dans MacOS.
    private var bundledExecutable: URL? {
        let fm = FileManager.default
        let res = Bundle.main.resourceURL?.appendingPathComponent("Engines")
        let candidates: [URL?] = switch self {
        // UZDoom (corrigé, MoltenVK récent) demande macOS 26 : ses bibliothèques
        // Homebrew l'exigent. Avant, GZDoom 4.14.2, autonome dès macOS 10.15.
        case .doom: Self.uzdoomAvailable
            ? [res?.appendingPathComponent("UZDoom.app/Contents/MacOS/uzdoom"),
               res?.appendingPathComponent("GZDoom.app/Contents/MacOS/gzdoom")]
            : [res?.appendingPathComponent("GZDoom.app/Contents/MacOS/gzdoom")]
        case .quake: [Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("vkquake")]
        case .wolf3d: [res?.appendingPathComponent("ECWolf.app/Contents/MacOS/ecwolf")]
        case .quake3: [res?.appendingPathComponent("Quake3e/quake3e")]
        case .rtcw: [res?.appendingPathComponent("iortcw.app/Contents/MacOS/iowolfsp")]
        case .quake4: [OpenQ4.executable]  // téléchargé sur demande
        case .doom3: [res?.appendingPathComponent("dhewm3.app/Contents/MacOS/dhewm3")]
        case .quake2: [res?.appendingPathComponent("yquake2/quake2")]
        case .build: [Raze.executable]      // téléchargé sur demande
        case .dos: [res?.appendingPathComponent("DOSBox Staging.app/Contents/MacOS/dosbox")]
        }
        return candidates.compactMap { $0 }.first { fm.isExecutableFile(atPath: $0.path) }
    }

    static var uzdoomAvailable: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
    }

    var prefKey: String { "enginePath.\(rawValue)" }

    /// Réglage explicite (une .app ou un exécutable), sinon le moteur embarqué.
    var executable: URL? {
        if let p = UserDefaults.standard.string(forKey: prefKey), !p.isEmpty {
            let url = URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
            if url.pathExtension == "app" { return Bundle(url: url)?.executableURL }
            return url
        }
        return bundledExecutable
    }

    var engineName: String {
        if let p = UserDefaults.standard.string(forKey: prefKey), !p.isEmpty {
            return (p as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
        switch self {
        case .doom: return bundledExecutable?.lastPathComponent == "gzdoom" ? "GZDoom" : "UZDoom"
        case .quake: return "vkQuake"
        case .wolf3d: return "ECWolf"
        case .quake3: return "Quake3e"
        case .rtcw: return "iortcw"
        case .quake4: return "openQ4"
        case .doom3: return "dhewm3"
        case .quake2: return "Yamagi Quake II"
        case .build: return "Raze"
        case .dos: return "DOSBox Staging"
        }
    }

    var userDirectory: URL { Prefs.userDataRoot.appendingPathComponent("engines/\(rawValue)") }
}

// MARK: - Catalogue des jeux connus

private struct KnownGame {
    let title: String
    let year: String
    let maker: String
    var players = 4
    /// Pour un WAD additionnel : le jeu de base qu'il demande.
    var base: String?
}

enum EngineCatalog {
    /// IWAD et extensions connus, par nom de fichier en minuscules.
    fileprivate static let doom: [String: KnownGame] = [
        "doom1.wad": .init(title: "Doom (shareware)", year: "1993", maker: "id Software"),
        "doom.wad": .init(title: "Doom", year: "1993", maker: "id Software"),
        "doom2.wad": .init(title: "Doom II: Hell on Earth", year: "1994", maker: "id Software"),
        "tnt.wad": .init(title: "Final Doom: TNT – Evilution", year: "1996", maker: "TeamTNT / id Software"),
        "plutonia.wad": .init(title: "Final Doom: The Plutonia Experiment", year: "1996", maker: "Dario et Milo Casali / id Software"),
        "heretic1.wad": .init(title: "Heretic (shareware)", year: "1994", maker: "Raven Software"),
        "heretic.wad": .init(title: "Heretic", year: "1994", maker: "Raven Software"),
        "hexen.wad": .init(title: "Hexen: Beyond Heretic", year: "1995", maker: "Raven Software"),
        "hexdd.wad": .init(title: "Hexen: Deathkings of the Dark Citadel", year: "1996", maker: "Raven Software", base: "hexen.wad"),
        "strife0.wad": .init(title: "Strife (démo)", year: "1996", maker: "Rogue Entertainment"),
        "strife1.wad": .init(title: "Strife", year: "1996", maker: "Rogue Entertainment"),
        "chex.wad": .init(title: "Chex Quest", year: "1996", maker: "Digital Café"),
        "chex3.wad": .init(title: "Chex Quest 3", year: "2008", maker: "Charles Jacobi"),
        "hacx.wad": .init(title: "HacX", year: "1997", maker: "Banjo Software"),
        "freedoom1.wad": .init(title: "Freedoom: Phase 1", year: "2024", maker: "Projet Freedoom"),
        "freedoom2.wad": .init(title: "Freedoom: Phase 2", year: "2024", maker: "Projet Freedoom"),
        "freedm.wad": .init(title: "FreeDM", year: "2024", maker: "Projet Freedoom"),
        "nerve.wad": .init(title: "Doom II: No Rest for the Living", year: "2010", maker: "Nerve Software", base: "doom2.wad"),
        "sigil.wad": .init(title: "Sigil", year: "2019", maker: "John Romero", base: "doom.wad"),
    ]
    /// Dossiers de jeux id Tech 2 et 3 (Quake II, Quake III, Return to Castle
    /// Wolfenstein…) : leurs .pk3 ne sont pas des mods de Doom.
    fileprivate static let foreignDirs: Set<String> = ["baseq3", "missionpack", "baseoa", "main", "etmain"]

    /// pak0.pk3, mp_pak1.pk3, sp_pak2.pk3 : archives id Tech 3, jamais des mods de Doom.
    fileprivate static func isIdTech3Archive(_ lower: String) -> Bool {
        lower.range(of: #"^(mp_|sp_)?pak\d+\.pk3$"#, options: .regularExpression) != nil
    }

    /// Fichiers chargés d'office par le moteur, à ne pas lister.
    fileprivate static let doomIgnored: Set<String> = ["voices.wad", "uzdoom.pk3", "gzdoom.pk3", "lights.pk3", "brightmaps.pk3", "game_support.pk3", "game_widescreen_gfx.pk3"]

    fileprivate static let quake: [String: KnownGame] = [
        "id1": .init(title: "Quake", year: "1996", maker: "id Software"),
        "hipnotic": .init(title: "Quake: Scourge of Armagon", year: "1997", maker: "Ritual Entertainment"),
        "rogue": .init(title: "Quake: Dissolution of Eternity", year: "1997", maker: "Rogue Entertainment"),
        "dopa": .init(title: "Quake: Dimension of the Past", year: "2016", maker: "MachineGames"),
        "mg1": .init(title: "Quake: Dimension of the Machine", year: "2021", maker: "MachineGames"),
    ]

    fileprivate static let quake3: [String: KnownGame] = [
        "baseq3": .init(title: "Quake III Arena", year: "1999", maker: "id Software"),
        "missionpack": .init(title: "Quake III: Team Arena", year: "2000", maker: "id Software"),
    ]

    fileprivate static let wolf: [String: KnownGame] = [
        "wl1": .init(title: "Wolfenstein 3D (shareware)", year: "1992", maker: "id Software", players: 1),
        "wl3": .init(title: "Wolfenstein 3D (épisodes 1 à 3)", year: "1992", maker: "id Software", players: 1),
        "wl6": .init(title: "Wolfenstein 3D", year: "1992", maker: "id Software", players: 1),
        "sdm": .init(title: "Spear of Destiny (démo)", year: "1992", maker: "id Software / FormGen", players: 1),
        "sod": .init(title: "Spear of Destiny", year: "1992", maker: "id Software / FormGen", players: 1),
        "sd2": .init(title: "Spear of Destiny: Return to Danger", year: "1994", maker: "FormGen", players: 1),
        "sd3": .init(title: "Spear of Destiny: Ultimate Challenge", year: "1994", maker: "FormGen", players: 1),
        "n3d": .init(title: "Super 3-D Noah's Ark", year: "1994", maker: "Wisdom Tree", players: 1),
    ]

    // MARK: Balayage (hors du fil principal, interruptible)

    /// Freedoom, s'il a été téléchargé depuis Borne.
    static var bundledFolders: [String] { [Freedoom.folder.path] }

    static func scan(_ folders: [String]) async -> [Machine]? {
        var games: [Machine] = []
        var seen = Set<String>()
        var doomFiles: [String: String] = [:]   // nom en minuscules → chemin, pour trouver les bases
        var pwads: [(URL, KnownGame?)] = []
        var quakeBase: String?                    // premier dossier de base Quake trouvé
        var quakeOrphans: [URL] = []              // extensions Quake rangées hors de leur base
        var q3Base: String?
        var q3Orphans: [URL] = []                 // Team Arena rangée hors de sa base
        var d3Base: URL?                          // dossier base de Doom 3
        var d3xpDirs: [URL] = []                  // Resurrection of Evil, souvent installée à part
        var archives: [URL] = []                  // jeux DOS en archive, lus à la fin
        let fm = FileManager.default

        func add(_ m: Machine) {
            if seen.insert(m.name).inserted { games.append(m) }
        }

        for folder in folders {
            let root = URL(fileURLWithPath: folder)
            guard let e = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                        options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            var count = 0
            while let url = e.nextObject() as? URL {
                count += 1
                if count & 255 == 0 && Task.isCancelled { return nil }
                if e.level > 7 { e.skipDescendants(); continue }
                let name = url.lastPathComponent
                let lower = name.lowercased()
                let ext = url.pathExtension.lowercased()
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

                if isDir {
                    // Quake II : baseq2 avec pak0.pak ; extensions à côté (xatrix, rogue, ctf).
                    if lower == "baseq2", caseInsensitiveChild(url, "pak0.pak") != nil {
                        for game in quake2Games(root: url.deletingLastPathComponent()) { add(game) }
                        e.skipDescendants(); continue
                    }
                    // Doom 3 : base avec pak000.pk4 ; Resurrection of Evil : d3xp, rattachée ensuite.
                    if lower == "base", caseInsensitiveChild(url, "pak000.pk4") != nil {
                        d3Base = d3Base ?? url
                        add(doom3Game(name: "doom3:base", title: "Doom 3", year: "2004", game: nil, base: url, d3xp: nil))
                        e.skipDescendants(); continue
                    }
                    if lower == "d3xp", caseInsensitiveChild(url, "pak000.pk4") != nil {
                        d3xpDirs.append(url)
                        e.skipDescendants(); continue
                    }
                    // Quake III : baseq3 avec pak0.pk3 ; Team Arena (missionpack) peut être ailleurs.
                    if lower == "baseq3", caseInsensitiveChild(url, "pak0.pk3") != nil {
                        let base = url.deletingLastPathComponent()
                        q3Base = q3Base ?? base.path
                        for game in quake3Games(in: base) { add(game) }
                        e.skipDescendants(); continue
                    }
                    // Quake 4 : q4base avec pak001.pk4.
                    if lower == "q4base", caseInsensitiveChild(url, "pak001.pk4") != nil {
                        add(quake4Game(base: url.deletingLastPathComponent()))
                        e.skipDescendants(); continue
                    }
                    // RTCW : dossier avec pak0.pk3 et sp_pak1.pk3 (solo), quel que soit
                    // son nom (Main d'origine, « rtcw » d'une installation RealRTCW…).
                    if caseInsensitiveChild(url, "sp_pak1.pk3") != nil, caseInsensitiveChild(url, "pak0.pk3") != nil {
                        add(rtcwGame(gameDir: url))
                        e.skipDescendants(); continue
                    }
                    if lower == "missionpack", caseInsensitiveChild(url, "pak0.pk3") != nil {
                        q3Orphans.append(url)
                        e.skipDescendants(); continue
                    }
                    if foreignDirs.contains(lower) { e.skipDescendants(); continue }
                    // Quake : un dossier id1 qui contient pak0.pak.
                    if lower == "id1", caseInsensitiveChild(url, "pak0.pak") != nil {
                        let base = url.deletingLastPathComponent()
                        quakeBase = quakeBase ?? base.path
                        for game in quakeGames(in: base) { add(game) }
                    } else if lower != "id1", let pak = caseInsensitiveChild(url, "pak0.pak"), isQuake1Pak(pak) {
                        quakeOrphans.append(url)
                    }
                    continue
                }

                switch ext {
                case "wad", "pk3", "pk7", "ipk3":
                    if doomIgnored.contains(lower) || isIdTech3Archive(lower) { continue }
                    doomFiles[lower] = doomFiles[lower] ?? url.path
                    if let k = doom[lower], k.base == nil {
                        add(doomGame(url, k))
                    } else if ext == "wad", doom[lower] == nil, isIWAD(url) {
                        add(doomGame(url, KnownGame(title: url.deletingPathExtension().lastPathComponent,
                                                    year: "", maker: "Doom (IWAD)")))
                    } else {
                        pwads.append((url, doom[lower]))
                    }
                case "grp", "rff", "dat":
                    // Jeux Build (Raze) : le fichier principal désigne le jeu.
                    if let k = build[lower] { add(buildGame(url, k)) }
                case "exe", "com":
                    // Jeux DOS : l'exécutable désigne le jeu.
                    if let m = DOSGames.game(folder: url.deletingLastPathComponent(), exe: name) { add(m) }
                case _ where DOSGames.archiveExtensions.contains(ext):
                    archives.append(url)
                default:
                    // Wolfenstein 3D : VSWAP.<ext> désigne le jeu.
                    if url.deletingPathExtension().lastPathComponent.lowercased() == "vswap", let k = wolf[ext] {
                        add(wolfGame(url.deletingLastPathComponent(), ext, k))
                    }
                }
            }
        }

        // Extensions Quake rangées à part (ExpDOE/ROGUE…) : rattachées à la base.
        if let base = quakeBase {
            for dir in quakeOrphans {
                let lower = dir.lastPathComponent.lowercased()
                guard !seen.contains("quake:\(lower)") else { continue }
                let k = quake[lower] ?? KnownGame(title: "\(dir.lastPathComponent) (mod Quake)", year: "", maker: "Mod pour Quake")
                var m = Machine(name: "quake:\(lower)")
                m.description = k.title
                m.year = k.year
                m.manufacturer = k.maker
                m.engine = Engine.quake.rawValue
                m.dataPath = base
                m.modArg = lower
                m.gamePath = dir.path
                fillCommon(&m, players: k.players)
                add(m)
            }
        }

        // Team Arena rangée à part : rattachée à Quake III.
        // Resurrection of Evil : a besoin des fichiers de Doom 3.
        if let base = d3Base, let dir = d3xpDirs.first {
            add(doom3Game(name: "doom3:d3xp", title: "Doom 3: Resurrection of Evil", year: "2005", game: "d3xp", base: base, d3xp: dir))
        }

        if let base = q3Base {
            for dir in q3Orphans where !seen.contains("quake3:missionpack") {
                var m = quake3Game(base: URL(fileURLWithPath: base), dir: "missionpack")
                m.gamePath = dir.path
                add(m)
            }
        }

        // Jeux DOS dans des archives : après les dossiers, qui l'emportent.
        if Task.isCancelled { return nil }
        for m in DOSGames.games(inArchives: archives) { add(m) }

        // WAD additionnels : rattachés à leur base, sinon à Doom II, sinon Freedoom 2.
        for (url, known) in pwads {
            if Task.isCancelled { return nil }
            let fallback = ["doom2.wad", "freedoom2.wad", "doom.wad", "freedoom1.wad"].first { doomFiles[$0] != nil }
            guard let baseName = known?.base ?? fallback, let base = doomFiles[baseName] else { continue }
            var m = doomGame(url, known ?? KnownGame(title: url.deletingPathExtension().lastPathComponent,
                                                     year: "", maker: "Mod pour \(doom[baseName]?.title ?? baseName)"))
            m.dataPath = base
            m.modArg = url.path
            m.cloneOf = nil
            add(m)
        }
        return games
    }

    private static func caseInsensitiveChild(_ dir: URL, _ name: String) -> URL? {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return items.first { $0.lowercased() == name }.map { dir.appendingPathComponent($0) }
    }

    /// Un PAK de Quake 1 contient progs.dat ; ceux de Quake II n'en ont pas.
    private static func isQuake1Pak(_ url: URL) -> Bool {
        guard let h = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? h.close() }
        guard let head = try? h.read(upToCount: 12), head.count == 12, head.prefix(4) == Data("PACK".utf8) else { return false }
        let offset = head.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        let length = head.subdata(in: 8..<12).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        guard length > 0, length < 64 * 20000, (try? h.seek(toOffset: UInt64(offset))) != nil,
              let dir = try? h.read(upToCount: Int(length)) else { return false }
        var i = 0
        while i + 64 <= dir.count {
            let name = dir.subdata(in: i..<(i + 56)).prefix { $0 != 0 }
            if String(decoding: name, as: UTF8.self).lowercased() == "progs.dat" { return true }
            i += 64
        }
        return false
    }

    private static func isIWAD(_ url: URL) -> Bool {
        guard let h = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? h.close() }
        return (try? h.read(upToCount: 4)) == Data("IWAD".utf8)
    }

    private static func doomGame(_ url: URL, _ k: KnownGame) -> Machine {
        var m = Machine(name: "doom:\(url.lastPathComponent.lowercased())")
        m.description = k.title
        m.year = k.year
        m.manufacturer = k.maker
        m.engine = Engine.doom.rawValue
        m.dataPath = url.path
        fillCommon(&m, players: k.players)
        return m
    }

    private static func quakeGames(in base: URL) -> [Machine] {
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(atPath: base.path)) ?? []
        var out: [Machine] = []
        for dir in dirs {
            let url = base.appendingPathComponent(dir)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let lower = dir.lowercased()
            let items = ((try? fm.contentsOfDirectory(atPath: url.path)) ?? []).map { $0.lowercased() }
            let playable = items.contains { $0.hasSuffix(".pak") || $0 == "progs.dat" || $0 == "maps" }
            guard playable else { continue }
            let k = quake[lower] ?? KnownGame(title: "\(dir) (mod Quake)", year: "", maker: "Mod pour Quake")
            var m = Machine(name: "quake:\(lower)")
            m.description = k.title
            m.year = k.year
            m.manufacturer = k.maker
            m.engine = Engine.quake.rawValue
            m.dataPath = base.path
            m.modArg = lower == "id1" ? nil : dir
            fillCommon(&m, players: k.players)
            out.append(m)
        }
        return out
    }

    private static func quake3Games(in base: URL) -> [Machine] {
        let fm = FileManager.default
        var out: [Machine] = []
        for dir in (try? fm.contentsOfDirectory(atPath: base.path)) ?? [] {
            let url = base.appendingPathComponent(dir)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let items = ((try? fm.contentsOfDirectory(atPath: url.path)) ?? []).map { $0.lowercased() }
            guard items.contains(where: { $0.hasSuffix(".pk3") }) else { continue }
            out.append(quake3Game(base: base, dir: dir))
        }
        return out
    }

    private static func quake3Game(base: URL, dir: String) -> Machine {
        let lower = dir.lowercased()
        let k = quake3[lower] ?? KnownGame(title: "\(dir) (mod Quake III)", year: "", maker: "Mod pour Quake III")
        var m = Machine(name: "quake3:\(lower)")
        m.description = k.title
        m.year = k.year
        m.manufacturer = k.maker
        m.engine = Engine.quake3.rawValue
        m.dataPath = base.path
        m.modArg = lower == "baseq3" ? nil : lower
        fillCommon(&m, players: k.players)
        return m
    }

    /// Fichiers principaux des jeux Build que Raze sait lancer.
    fileprivate static let build: [String: KnownGame] = [
        "duke3d.grp": .init(title: "Duke Nukem 3D", year: "1996", maker: "3D Realms"),
        "blood.rff": .init(title: "Blood", year: "1997", maker: "Monolith Productions"),
        "sw.grp": .init(title: "Shadow Warrior", year: "1997", maker: "3D Realms"),
        "redneck.grp": .init(title: "Redneck Rampage", year: "1997", maker: "Xatrix Entertainment"),
        "stuff.dat": .init(title: "Exhumed (PowerSlave)", year: "1996", maker: "Lobotomy Software"),
        "nam.grp": .init(title: "NAM", year: "1998", maker: "TNT Team"),
        "napalm.grp": .init(title: "Napalm", year: "1998", maker: "TNT Team"),
        "ww2gi.grp": .init(title: "World War II GI", year: "1999", maker: "TNT Team"),
    ]

    private static func buildGame(_ url: URL, _ k: KnownGame) -> Machine {
        var m = Machine(name: "build:\(url.lastPathComponent.lowercased())")
        m.description = k.title
        m.year = k.year
        m.manufacturer = k.maker
        m.engine = Engine.build.rawValue
        m.dataPath = url.path
        fillCommon(&m, players: 1)
        return m
    }

    private static let quake2Packs: [(dir: String, title: String, year: String, maker: String)] = [
        ("baseq2", "Quake II", "1997", "id Software"),
        ("xatrix", "Quake II: The Reckoning", "1998", "Xatrix Entertainment"),
        ("rogue", "Quake II: Ground Zero", "1998", "Rogue Entertainment"),
        ("ctf", "Quake II: Capture The Flag", "1998", "id Software"),
    ]

    private static func quake2Games(root: URL) -> [Machine] {
        quake2Packs.compactMap { pack in
            guard let dir = caseInsensitiveChild(root, pack.dir), caseInsensitiveChild(dir, "pak0.pak") != nil else { return nil }
            var m = Machine(name: "quake2:\(pack.dir)")
            m.description = pack.title
            m.year = pack.year
            m.manufacturer = pack.maker
            m.engine = Engine.quake2.rawValue
            m.dataPath = root.path
            m.modArg = pack.dir == "baseq2" ? nil : pack.dir
            fillCommon(&m, players: pack.dir == "ctf" ? 16 : 1)
            return m
        }
    }

    private static func doom3Game(name: String, title: String, year: String, game: String?, base: URL, d3xp: URL?) -> Machine {
        var m = Machine(name: name)
        m.description = title
        m.year = year
        m.manufacturer = game == nil ? "id Software" : "Nerve Software / id Software"
        m.engine = Engine.doom3.rawValue
        m.dataPath = base.path
        m.modArg = game
        m.gamePath = d3xp?.path
        fillCommon(&m, players: 1)
        return m
    }

    private static func quake4Game(base: URL) -> Machine {
        var m = Machine(name: "quake4:base")
        m.description = "Quake 4"
        m.year = "2005"
        m.manufacturer = "Raven Software / id Software"
        m.engine = Engine.quake4.rawValue
        m.dataPath = base.path
        fillCommon(&m, players: 1)
        return m
    }

    private static func rtcwGame(gameDir: URL) -> Machine {
        // Une entrée par langue : sp_pak1.pk3 porte les textes et menus localisés.
        let lang = caseInsensitiveChild(gameDir, "sp_pak1.pk3").flatMap(rtcwLanguage)
        var m = Machine(name: "rtcw:sp" + (lang.map { ":\($0.code)" } ?? ""))
        m.description = "Return to Castle Wolfenstein" + (lang.map { " (\($0.name))" } ?? "")
        m.year = "2001"
        m.manufacturer = "Gray Matter / id Software"
        m.engine = Engine.rtcw.rawValue
        m.dataPath = gameDir.path
        fillCommon(&m, players: 1)
        return m
    }

    /// Langue d'une version de RTCW, d'après le premier bouton de son menu principal.
    private static func rtcwLanguage(_ spPak1: URL) -> (code: String, name: String)? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-p", spPak1.path, "ui/main.menu"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let menu = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).uppercased()
        p.waitUntilExit()
        let known: [(String, String, String)] = [
            ("\"GIOCA\"", "it", "italien"), ("\"JUGAR\"", "es", "espagnol"), ("\"JOUER\"", "fr", "français"),
            ("\"SPIELEN\"", "de", "allemand"), ("\"PLAY\"", "en", "anglais"),
        ]
        return known.first { menu.contains($0.0) }.map { ($0.1, $0.2) }
    }

    private static func wolfGame(_ dir: URL, _ ext: String, _ k: KnownGame) -> Machine {
        var m = Machine(name: "wolf3d:\(ext)")
        m.description = k.title
        m.year = k.year
        m.manufacturer = k.maker
        m.engine = Engine.wolf3d.rawValue
        m.dataPath = dir.path
        m.modArg = ext
        fillCommon(&m, players: k.players)
        return m
    }

    private static func fillCommon(_ m: inout Machine, players: Int) {
        m.status = "good"
        m.emulation = "good"
        m.savestate = true
        m.players = players
        m.controls = ["keyboard", "mouse"]
        m.screen = "raster"
        m.needsFiles = false
        m.sourcefile = Engine(rawValue: m.engine ?? "")?.engineName ?? ""
    }
}

// MARK: - Lancement

enum EngineLaunchError: Error {
    /// Quake III sans le patch 1.32 : à télécharger après acceptation de la licence d'id.
    case needsQuake3Patch
    /// Quake 4 : openQ4 à télécharger d'abord.
    case needsOpenQ4
    /// Quake 4 d'origine : la mise à jour 1.4.2 d'id Software, après acceptation de sa licence.
    case needsQuake4Patch
    /// Doom 3 d'origine : la mise à jour 1.3.1 d'id Software, après acceptation de sa licence.
    case needsDoom3Patch
    /// Jeux Build : Raze à télécharger d'abord.
    case needsRaze
    /// Jeu DOS en archive : à décompresser dans le dossier utilisateur.
    case needsExtraction
}

struct EngineLaunch {
    let executable: URL
    let arguments: [String]
    let directory: URL
    let environment: [String: String]
}

extension Engine {
    func launch(for m: Machine) throws -> EngineLaunch {
        if self == .quake4 && executable == nil {
            guard OpenQ4.isSupported else {
                throw MAMERunner.Failure(message: "openQ4, le moteur de Quake 4, n'existe que pour les Mac Apple silicon.")
            }
            throw EngineLaunchError.needsOpenQ4
        }
        if self == .build && executable == nil { throw EngineLaunchError.needsRaze }
        guard let exe = executable else {
            throw MAMERunner.Failure(message: "Le moteur \(title) est introuvable. Indiquez-le dans les réglages.")
        }
        // Jeu DOS déjà décompressé : l'archive d'origine n'est plus nécessaire.
        let extracted = self == .dos && DOSGames.isArchive(m) && DOSGames.isExtracted(m)
        guard let data = m.dataPath, extracted || FileManager.default.fileExists(atPath: data) else {
            throw MAMERunner.Failure(message: "Les fichiers du jeu sont introuvables : \(m.dataPath ?? "?"). Le disque est-il branché ?")
        }
        let user = userDirectory
        try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        var env = ProcessInfo.processInfo.environment
        // Dossier personnel vu par le moteur : ce qu'il range d'office dans
        // Documents ou Application Support reste sous engines/<moteur>/home.
        let home = user.appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        env["CFFIXED_USER_HOME"] = home.path
        var args: [String]
        var cwd = user

        switch self {
        case .doom:
            let stem = URL(fileURLWithPath: m.modArg ?? data).deletingPathExtension().lastPathComponent.lowercased()
            let saves = user.appendingPathComponent("saves/\(stem)")
            try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
            let extra = user.appendingPathComponent("borne.cfg")
            // Tir aussi sur X : Ctrl+flèche appartient à macOS.
            try "bind x +attack\n".write(to: extra, atomically: true, encoding: .utf8)
            // Premier lancement : Vulkan (vers Metal) plutôt qu'OpenGL, déprécié par
            // Apple. Le moteur lit ce choix avant la ligne de commande ; celui fait
            // ensuite dans son menu est respecté.
            let ini = user.appendingPathComponent("\(engineName.lowercased()).ini")
            if !FileManager.default.fileExists(atPath: ini.path) {
                try "[GlobalSettings]\nvid_preferbackend=1\n".write(to: ini, atomically: true, encoding: .utf8)
            }
            args = ["-iwad", data]
            if let pwad = m.modArg { args += ["-file", pwad] }
            args += ["-config", user.appendingPathComponent("\(engineName.lowercased()).ini").path,
                     "-savedir", saves.path,
                     "-shotdir", user.appendingPathComponent("shots").path,
                     "-exec", extra.path,
                     "+vid_fullscreen", Prefs.windowed ? "0" : "1"]

        case .quake:
            let id1 = user.appendingPathComponent("id1")
            try FileManager.default.createDirectory(at: id1, withIntermediateDirectories: true)
            try "bind x +attack\n".write(to: id1.appendingPathComponent("borne.cfg"), atomically: true, encoding: .utf8)
            if let game = m.modArg, let src = m.gamePath {
                try Self.linkQuakeGame(name: game, from: URL(fileURLWithPath: src), into: user)
            }
            args = ["-basedir", data, "-userdir", user.path]
            if let game = m.modArg { args += ["-game", game] }
            args += [Prefs.windowed ? "-window" : "-fullscreen", "+exec", "borne.cfg"]
            env.merge(Self.vulkanEnvironment()) { _, new in new }

        case .quake3:
            let fm = FileManager.default
            let baseq3 = user.appendingPathComponent("baseq3")
            try fm.createDirectory(at: baseq3, withIntermediateDirectories: true)
            try "bind x +attack\n".write(to: baseq3.appendingPathComponent("autoexec.cfg"), atomically: true, encoding: .utf8)
            // Vieux CD : sans le patch 1.32 (pak8.pk3), les moteurs modernes refusent de démarrer.
            if Quake3Patch.isNeeded(base: URL(fileURLWithPath: data)) {
                guard Quake3Patch.isInstalled else { throw EngineLaunchError.needsQuake3Patch }
                try Quake3Patch.link(into: user)
            }
            if let game = m.modArg, let src = m.gamePath {
                try Self.linkQuakeGame(name: game, from: URL(fileURLWithPath: src), into: user)
            }
            args = ["+set", "fs_basepath", data, "+set", "fs_homepath", user.path]
            if let game = m.modArg { args += ["+set", "fs_game", game] }
            args += ["+set", "r_fullscreen", Prefs.windowed ? "0" : "1"]
            env.merge(Self.vulkanEnvironment()) { _, new in new }

        case .build:
            let stem = URL(fileURLWithPath: data).deletingPathExtension().lastPathComponent.lowercased()
            let saves = user.appendingPathComponent("saves/\(stem)")
            try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
            // Premier lancement : sans le sélecteur de jeu, en Vulkan.
            let ini = user.appendingPathComponent("raze.ini")
            if !FileManager.default.fileExists(atPath: ini.path) {
                try "[GlobalSettings]\nqueryiwad=false\nvid_preferbackend=1\n".write(to: ini, atomically: true, encoding: .utf8)
            }
            args = ["-iwad", data, "-config", ini.path, "-savedir", saves.path,
                    "-shotdir", user.appendingPathComponent("shots").path,
                    "+vid_fullscreen", Prefs.windowed ? "0" : "1"]

        case .quake2:
            // Yamagi écrit dans $HOME/.yq2 (pas par les API de Foundation) : HOME à part.
            let game = m.modArg ?? "baseq2"
            let cfg = home.appendingPathComponent(".yq2/\(game)")
            try FileManager.default.createDirectory(at: cfg, withIntermediateDirectories: true)
            try "bind x +attack\n".write(to: cfg.appendingPathComponent("autoexec.cfg"), atomically: true, encoding: .utf8)
            env["HOME"] = home.path
            args = ["-datadir", data, "+set", "vid_renderer", "gl3",
                    "+set", "vid_fullscreen", Prefs.windowed ? "0" : "1"]
            if let pack = m.modArg { args += ["+set", "game", pack] }

        case .doom3:
            // dhewm3 veut base et d3xp côte à côte sous fs_basepath, en version 1.3.1 :
            // dossiers de liens dans le dossier utilisateur, vers les fichiers du jeu
            // (où qu'ils soient) et, pour un DVD d'origine, ceux du patch.
            let fm = FileManager.default
            let base = URL(fileURLWithPath: data)
            let d3xp = m.gamePath.map { URL(fileURLWithPath: $0) }
            let patched = Doom3Patch.isNeeded(base: base, d3xp: d3xp)
            if patched && !Doom3Patch.isInstalled { throw EngineLaunchError.needsDoom3Patch }
            let root = user.appendingPathComponent("data")
            try? fm.removeItem(at: root)
            for (game, dir) in [("base", base), ("d3xp", d3xp)] {
                guard let dir else { continue }
                let dst = root.appendingPathComponent(game)
                try fm.createDirectory(at: dst, withIntermediateDirectories: true)
                // Pas le code de jeu d'origine (game*.pk4) : dhewm3 a le sien.
                var sources = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension.lowercased() == "pk4" && !$0.lastPathComponent.lowercased().hasPrefix("game") }
                if patched { sources += Doom3Patch.files(for: game) }
                for src in sources {
                    let link = dst.appendingPathComponent(src.lastPathComponent.lowercased())
                    if !fm.fileExists(atPath: link.path) { try fm.createSymbolicLink(at: link, withDestinationURL: src) }
                }
            }
            let saves = user.appendingPathComponent("saves")
            try fm.createDirectory(at: saves.appendingPathComponent(m.modArg ?? "base"), withIntermediateDirectories: true)
            try "bind x _attack\n".write(to: saves.appendingPathComponent("\(m.modArg ?? "base")/autoexec.cfg"), atomically: true, encoding: .utf8)
            args = ["+set", "fs_basepath", root.path, "+set", "fs_savepath", saves.path,
                    "+set", "fs_configpath", saves.path]
            if let game = m.modArg { args += ["+set", "fs_game", game] }
            args += ["+set", "r_fullscreen", Prefs.windowed ? "0" : "1"]

        case .quake4:
            let base = user.appendingPathComponent("baseoq4")
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            try "bind x _attack\n".write(to: base.appendingPathComponent("autoexec.cfg"), atomically: true, encoding: .utf8)
            // DVD d'origine (jusqu'à pak012) : openQ4 veut les données de la 1.4.2.
            if Quake4Patch.isNeeded(base: URL(fileURLWithPath: data)) {
                guard Quake4Patch.isInstalled else { throw EngineLaunchError.needsQuake4Patch }
                try Quake4Patch.link(into: user)
            }
            args = ["+set", "fs_basepath", data, "+set", "fs_homepath", user.path,
                    "+set", "fs_savepath", user.path, "+set", "fs_cachepath", user.appendingPathComponent("cache").path,
                    "+set", "r_fullscreen", Prefs.windowed ? "0" : "1"]

        case .rtcw:
            let main = user.appendingPathComponent("main")
            try FileManager.default.createDirectory(at: main, withIntermediateDirectories: true)
            try "bind x +attack\n".write(to: main.appendingPathComponent("autoexec.cfg"), atomically: true, encoding: .utf8)
            let base = try Self.rtcwBase(gameDir: URL(fileURLWithPath: data), in: user)
            args = ["+set", "fs_basepath", base.path, "+set", "fs_homepath", user.path,
                    "+set", "r_fullscreen", Prefs.windowed ? "0" : "1"]

        case .dos:
            // DOSBox Staging range sa configuration dans ~/Library/Preferences/DOSBox.
            env["HOME"] = home.path
            args = try DOSGames.arguments(for: m, user: user)

        case .wolf3d:
            let cfg = user.appendingPathComponent("ecwolf.cfg")
            if !FileManager.default.fileExists(atPath: cfg.path) {
                // Configuration de départ : tir sur X (120) plutôt que Ctrl (306).
                try "Keyboard_Attack = 120;\n".write(to: cfg, atomically: true, encoding: .utf8)
            }
            let saves = user.appendingPathComponent("saves")
            try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
            // ECWolf cherche les données dans le dossier courant ; il ne les modifie pas.
            cwd = URL(fileURLWithPath: data)
            args = ["--data", m.modArg ?? "wl6", "--config", cfg.path, "--savedir", saves.path]
            if !Prefs.windowed { args.append("--fullscreen") }
        }
        return EngineLaunch(executable: exe, arguments: args, directory: cwd, environment: env)
    }

    /// Extension rangée hors de la base : un vrai dossier dans le dossier
    /// utilisateur, avec des liens vers ses fichiers. vkQuake y lit les PAK, et
    /// ce qu'il écrit (sauvegardes, réglages) reste dans le vrai dossier.
    static func linkQuakeGame(name: String, from src: URL, into user: URL) throws {
        let fm = FileManager.default
        let dir = user.appendingPathComponent(name)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for item in try fm.contentsOfDirectory(atPath: src.path) where !item.hasPrefix(".") {
            // Les .cfg pourraient être réécrits à travers le lien : on ne les lie pas.
            if item.lowercased().hasSuffix(".cfg") { continue }
            let link = dir.appendingPathComponent(item)
            if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil { try fm.removeItem(at: link) }
            if fm.fileExists(atPath: link.path) { continue }
            try fm.createSymbolicLink(at: link, withDestinationURL: src.appendingPathComponent(item))
        }
    }

    /// Chargeur Vulkan embarqué et pilote : KosmicKrisp sur Apple silicon avec
    /// macOS 26 s'il est fourni, sinon MoltenVK.
    /// Base de RTCW refaite à chaque lancement dans le dossier utilisateur :
    /// base/main avec des liens vers les seuls fichiers du jeu d'origine. Le
    /// dossier du jeu peut porter un autre nom que Main et contenir les fichiers
    /// d'un mod à moteur propre (RealRTCW : z_realrtcw_*.pk3, DLL Windows), que
    /// iortcw ne doit pas charger.
    static func rtcwBase(gameDir: URL, in user: URL) throws -> URL {
        let fm = FileManager.default
        let base = user.appendingPathComponent("base")
        let main = base.appendingPathComponent("main")
        try? fm.removeItem(at: base)
        try fm.createDirectory(at: main, withIntermediateDirectories: true)
        let retail: Set<String> = ["pak0.pk3", "sp_pak1.pk3", "sp_pak2.pk3", "sp_pak3.pk3", "sp_pak4.pk3"]
        for file in try fm.contentsOfDirectory(atPath: gameDir.path) where retail.contains(file.lowercased()) {
            try fm.createSymbolicLink(at: main.appendingPathComponent(file.lowercased()),
                                      withDestinationURL: gameDir.appendingPathComponent(file))
        }
        return base
    }

    static func vulkanEnvironment() -> [String: String] {
        guard let frameworks = Bundle.main.privateFrameworksURL,
              let res = Bundle.main.resourceURL?.appendingPathComponent("vulkan") else { return [:] }
        var env = ["SDL_VULKAN_LIBRARY": frameworks.appendingPathComponent("libvulkan.1.dylib").path]
        let kk = res.appendingPathComponent("kosmickrisp_icd.json")
        let mvk = res.appendingPathComponent("MoltenVK_icd.json")
        #if arch(arm64)
        let wantsKK = ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
            && UserDefaults.standard.string(forKey: "vulkanDriver") != "moltenvk"
        #else
        let wantsKK = false
        #endif
        let driver = wantsKK && FileManager.default.fileExists(atPath: kk.path) ? kk : mvk
        if FileManager.default.fileExists(atPath: driver.path) { env["VK_DRIVER_FILES"] = driver.path }
        return env
    }

    static var vulkanDriverName: String {
        let env = vulkanEnvironment()
        return env["VK_DRIVER_FILES"]?.contains("kosmickrisp") == true ? "KosmicKrisp" : "MoltenVK"
    }
}
