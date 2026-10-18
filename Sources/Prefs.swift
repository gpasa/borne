import Foundation

/// Réglages, lus partout par UserDefaults (les vues passent par @AppStorage
/// avec les mêmes clés).
///
/// Deux mondes séparés :
/// - le disque des jeux (SSD externe) n'est que lu : ROM, samples, artwork,
///   cheat, packs d'images ;
/// - tout ce que MAME écrit (réglages par jeu, NVRAM, sauvegardes d'état,
///   captures, enregistrements, diff des CHD, scores) va dans le dossier
///   utilisateur, et mame y est lancé pour que rien d'imprévu n'atterrisse ailleurs.
enum Prefs {
    static let mamePathKey = "mamePath"
    static let mediaPathKey = "mediaPath"
    static let romPathsKey = "romPaths"
    static let artworkPathKey = "artworkPath"
    static let userDataPathKey = "userDataPath"
    static let windowedKey = "windowed"
    static let extraArgsKey = "extraArgs"

    /// Repli quand mame n'est pas embarqué (compilation sans lui) : Homebrew.
    static let defaultMamePath = "/opt/homebrew/bin/mame"

    private static func path(_ key: String) -> String? {
        let p = UserDefaults.standard.string(forKey: key) ?? ""
        return p.isEmpty ? nil : (p as NSString).expandingTildeInPath
    }

    /// mame embarqué dans l'app (Contents/MacOS/mame), s'il y est.
    static var bundledMameURL: URL? {
        guard let url = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("mame"),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }

    /// Réglage explicite, sinon mame embarqué, sinon celui du dossier de développement.
    static var mameURL: URL {
        if let p = path(mamePathKey) { return URL(fileURLWithPath: p) }
        return bundledMameURL ?? URL(fileURLWithPath: defaultMamePath)
    }

    static var mameURLPlaceholder: String {
        bundledMameURL != nil ? "mame intégré à Borne" : defaultMamePath
    }

    /// Dossier de l'installation de mame : hash/, plugins/, bgfx/, language/…
    /// Pour le mame embarqué, Contents/Resources/mame ; sinon, à côté du binaire.
    static var mameDirectory: URL {
        if mameURL == bundledMameURL, let r = Bundle.main.resourceURL {
            return r.appendingPathComponent("mame")
        }
        return mameURL.deletingLastPathComponent()
    }

    // MARK: Disque des jeux (lecture seule)

    /// Racine du disque des jeux ; par défaut, le dossier de mame.
    static var mediaRoot: URL {
        path(mediaPathKey).map { URL(fileURLWithPath: $0) } ?? mameDirectory
    }

    /// Une ligne par dossier ; par défaut roms/ sur le disque des jeux.
    static var romPaths: [String] {
        let list = (UserDefaults.standard.string(forKey: romPathsKey) ?? "")
            .split(separator: "\n").map { ($0 as NSString).expandingTildeInPath }
        return list.isEmpty ? [mediaRoot.appendingPathComponent("roms").path] : list
    }

    /// Adopte le dossier choisi par l'utilisateur, qu'il ait pris le dossier
    /// roms lui-même ou celui qui le contient. Rend une phrase qui dit ce
    /// qui a été compris.
    @discardableResult
    static func adoptGamesFolder(_ url: URL) -> String {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
        var isDir: ObjCBool = false
        let hasRomsSubfolder = fm.fileExists(atPath: url.appendingPathComponent("roms").path, isDirectory: &isDir)
            && isDir.boolValue
        let hasSets = entries.contains { ["zip", "7z"].contains(($0 as NSString).pathExtension.lowercased()) }
        let d = UserDefaults.standard
        if hasRomsSubfolder || (!hasSets && url.lastPathComponent.lowercased() != "roms") {
            // Racine du disque des jeux : roms/, samples/, artwork/… dedans.
            d.set(url.path, forKey: mediaPathKey)
            d.removeObject(forKey: romPathsKey)
            return "Disque des jeux : \(url.path) (ROM dans « roms »)."
        }
        // Le dossier des ROM lui-même : samples/, artwork/… à côté de lui.
        d.set(url.deletingLastPathComponent().path, forKey: mediaPathKey)
        d.set(url.path, forKey: romPathsKey)
        return "ROM : \(url.path) ; samples et artwork cherchés à côté."
    }

    static let gamesFolderPrompt = "Choisissez le dossier « roms », ou le dossier qui le contient (avec samples, artwork…). Les deux conviennent."

    /// Racine des packs d'images : snap/, titles/, marquees/, flyers/, cabinets/, cpanel/.
    static var artworkRoot: URL {
        path(artworkPathKey).map { URL(fileURLWithPath: $0) } ?? mediaRoot
    }

    // MARK: Dossier utilisateur (écriture)

    static var defaultUserDataPath: String {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Borne/MAME").path
    }

    static var userDataRoot: URL {
        URL(fileURLWithPath: path(userDataPathKey) ?? defaultUserDataPath, isDirectory: true)
    }

    /// Les sous-dossiers où MAME écrit, avec l'option qui les désigne.
    static let writableDirectories: [(option: String, folder: String)] = [
        ("-cfg_directory", "cfg"),
        ("-nvram_directory", "nvram"),
        ("-state_directory", "sta"),
        ("-input_directory", "inp"),
        ("-snapshot_directory", "snap"),
        ("-diff_directory", "diff"),
        ("-comment_directory", "comments"),
        ("-share_directory", "share"),
    ]

    static var userSnapshots: URL { userDataRoot.appendingPathComponent("snap") }

    /// Copies locales des jeux installés sur le Mac.
    static var localROMs: URL { userDataRoot.appendingPathComponent("roms") }
    static var localSamples: URL { userDataRoot.appendingPathComponent("samples") }

    /// Dossiers où chercher les sets : copies locales d'abord.
    static var searchROMPaths: [String] { [localROMs.path] + romPaths }

    /// Crée le dossier utilisateur et ses sous-dossiers.
    static func prepareUserData() throws {
        let fm = FileManager.default
        for (_, folder) in writableDirectories + [("", "ini"), ("", "roms"), ("", "samples")] {
            try fm.createDirectory(at: userDataRoot.appendingPathComponent(folder),
                                   withIntermediateDirectories: true)
        }
    }

    // MARK: Lancement

    static var windowed: Bool {
        UserDefaults.standard.object(forKey: windowedKey) as? Bool ?? true
    }

    static var extraArgs: [String] {
        (UserDefaults.standard.string(forKey: extraArgsKey) ?? "")
            .split(separator: " ").map(String.init)
    }

    /// Tous les chemins passés à mame, en absolu puisqu'il tourne dans le
    /// dossier utilisateur et non dans le sien.
    static var pathArguments: [String] {
        let mame = mameDirectory.path
        let media = mediaRoot.path
        let user = userDataRoot.path
        var args = [
            // Lecture : copies locales d'abord, puis disque des jeux et
            // installation de mame. mame prend le premier fichier trouvé.
            "-rompath", searchROMPaths.joined(separator: ";"),
            "-samplepath", "\(localSamples.path);\(media)/samples;\(mame)/samples",
            "-artpath", "\(media)/artwork;\(mame)/artwork",
            "-cheatpath", "\(media)/cheat",
            "-ctrlrpath", "\(mame)/ctrlr",
            "-hashpath", "\(mame)/hash",
            "-pluginspath", "\(mame)/plugins",
            "-languagepath", "\(mame)/language",
            "-bgfx_path", "\(mame)/bgfx",
            "-fontpath", mame,
            "-crosshairpath", "\(mame)/crosshair",
            // Écriture : uniquement le dossier utilisateur.
            "-inipath", "\(user)/ini",
            "-homepath", user,
        ]
        for (option, folder) in writableDirectories {
            args += [option, "\(user)/\(folder)"]
        }
        return args
    }

    /// Rendu et touches. bgfx (le défaut de MAME) décale l'image du jeu dans
    /// son décor quand la fenêtre change de taille sur un écran Retina ;
    /// OpenGL reste juste. Les options en plus passent après et l'emportent.
    static var displayArguments: [String] {
        var args = ["-video", "opengl"]
        let ctrlr = mameDirectory.appendingPathComponent("ctrlr/borne_mac.cfg")
        if FileManager.default.fileExists(atPath: ctrlr.path) { args += ["-ctrlr", "borne_mac"] }
        return args
    }

    /// Chemins de lecture absents (disque débranché, par exemple).
    static var missingROMPaths: [String] {
        romPaths.filter { !FileManager.default.fileExists(atPath: $0) }
    }

    static var supportDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Borne", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
