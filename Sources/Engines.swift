import AppKit
import Foundation

/// Moteurs de jeux PC embarqués : Doom (UZDoom, ou GZDoom sur Intel),
/// Quake (vkQuake) et Wolfenstein 3D (ECWolf). Les données des jeux restent
/// où elles sont, en lecture seule ; chaque moteur écrit dans
/// <dossier utilisateur>/engines/<moteur>.
enum Engine: String, CaseIterable, Codable, Identifiable {
    case doom, quake, wolf3d

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doom: "Doom"
        case .quake: "Quake"
        case .wolf3d: "Wolfenstein 3D"
        }
    }

    var symbol: String {
        switch self {
        case .doom: "flame"
        case .quake: "bolt"
        case .wolf3d: "shield.lefthalf.filled"
        }
    }

    // MARK: Exécutables

    /// Moteur embarqué : app dans Resources/Engines, ou binaire dans MacOS.
    private var bundledExecutable: URL? {
        let fm = FileManager.default
        let res = Bundle.main.resourceURL?.appendingPathComponent("Engines")
        let candidates: [URL?] = switch self {
        case .doom: [res?.appendingPathComponent("UZDoom.app/Contents/MacOS/uzdoom"),
                     res?.appendingPathComponent("GZDoom.app/Contents/MacOS/gzdoom")]
        case .quake: [Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("vkquake")]
        case .wolf3d: [res?.appendingPathComponent("ECWolf.app/Contents/MacOS/ecwolf")]
        }
        return candidates.compactMap { $0 }.first { fm.isExecutableFile(atPath: $0.path) }
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
    /// Fichiers chargés d'office par le moteur, à ne pas lister.
    fileprivate static let doomIgnored: Set<String> = ["voices.wad", "uzdoom.pk3", "gzdoom.pk3", "lights.pk3", "brightmaps.pk3", "game_support.pk3", "game_widescreen_gfx.pk3"]

    fileprivate static let quake: [String: KnownGame] = [
        "id1": .init(title: "Quake", year: "1996", maker: "id Software"),
        "hipnotic": .init(title: "Quake: Scourge of Armagon", year: "1997", maker: "Ritual Entertainment"),
        "rogue": .init(title: "Quake: Dissolution of Eternity", year: "1997", maker: "Rogue Entertainment"),
        "dopa": .init(title: "Quake: Dimension of the Past", year: "2016", maker: "MachineGames"),
        "mg1": .init(title: "Quake: Dimension of the Machine", year: "2021", maker: "MachineGames"),
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
                    // Quake : un dossier id1 qui contient pak0.pak.
                    if lower == "id1", let pak = caseInsensitiveChild(url, "pak0.pak") {
                        _ = pak
                        let base = url.deletingLastPathComponent()
                        for game in quakeGames(in: base) { add(game) }
                    }
                    continue
                }

                switch ext {
                case "wad", "pk3", "pk7", "ipk3":
                    if doomIgnored.contains(lower) { continue }
                    doomFiles[lower] = doomFiles[lower] ?? url.path
                    if let k = doom[lower], k.base == nil {
                        add(doomGame(url, k))
                    } else if ext == "wad", doom[lower] == nil, isIWAD(url) {
                        add(doomGame(url, KnownGame(title: url.deletingPathExtension().lastPathComponent,
                                                    year: "", maker: "Doom (IWAD)")))
                    } else {
                        pwads.append((url, doom[lower]))
                    }
                default:
                    // Wolfenstein 3D : VSWAP.<ext> désigne le jeu.
                    if url.deletingPathExtension().lastPathComponent.lowercased() == "vswap", let k = wolf[ext] {
                        add(wolfGame(url.deletingLastPathComponent(), ext, k))
                    }
                }
            }
        }

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

struct EngineLaunch {
    let executable: URL
    let arguments: [String]
    let directory: URL
    let environment: [String: String]
}

extension Engine {
    func launch(for m: Machine) throws -> EngineLaunch {
        guard let exe = executable else {
            throw MAMERunner.Failure(message: "Le moteur \(title) est introuvable. Indiquez-le dans les réglages.")
        }
        guard let data = m.dataPath, FileManager.default.fileExists(atPath: data) else {
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
            args = ["-basedir", data, "-userdir", user.path]
            if let game = m.modArg { args += ["-game", game] }
            args += [Prefs.windowed ? "-window" : "-fullscreen", "+exec", "borne.cfg"]
            env.merge(Self.vulkanEnvironment()) { _, new in new }

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

    /// Chargeur Vulkan embarqué et pilote : KosmicKrisp sur Apple silicon avec
    /// macOS 26 s'il est fourni, sinon MoltenVK.
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
