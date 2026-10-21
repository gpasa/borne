import Foundation

/// Diagnostic d'un jeu : ce qui est là, ce qui manque, et comment le compléter.
struct DiagnosticItem: Identifiable, Equatable {
    enum State: Equatable { case ok, warning, missing, info }

    let id = UUID()
    var state: State
    var title: String
    var detail: String?
    var fix: DiagnosticFix?

    static func == (a: DiagnosticItem, b: DiagnosticItem) -> Bool {
        a.state == b.state && a.title == b.title && a.detail == b.detail && a.fix == b.fix
    }
}

/// Ce que Borne sait faire lui-même pour compléter un jeu.
enum DiagnosticFix: Equatable {
    /// Moteur à télécharger ou mise à jour d'id Software à accepter.
    case offer(EngineLaunchError)
    case rescan
    case verify
    case showSettings
    case revealUserData

    var label: String {
        switch self {
        case .offer(.needsOpenQ4): String(localized: "Télécharger openQ4…")
        case .offer(.needsRaze): String(localized: "Télécharger Raze…")
        case .offer(.needsExtraction): String(localized: "Décompresser maintenant")
        case .offer(.needsScummVM): String(localized: "Télécharger ScummVM…")
        case .offer: String(localized: "Installer la mise à jour…")
        case .rescan: String(localized: "Relire les dossiers")
        case .verify: String(localized: "Vérifier à nouveau")
        case .showSettings: String(localized: "Ouvrir les réglages")
        case .revealUserData: String(localized: "Afficher dans le Finder")
        }
    }
}

enum Diagnostic {
    // MARK: Jeux PC (instantané : rien que des fichiers à regarder)

    static func engineGame(_ m: Machine) -> [DiagnosticItem] {
        guard let engine = m.engineKind else { return [] }
        var items: [DiagnosticItem] = []

        // Le moteur.
        if engine.executable != nil {
            let how = switch engine {
            case .quake4, .build, .scummvm: String(localized: "téléchargé")
            default: UserDefaults.standard.string(forKey: "enginePath.\(engine.rawValue)")?.isEmpty == false ? String(localized: "le vôtre") : String(localized: "inclus dans Borne")
            }
            items.append(.init(state: .ok, title: String(localized: "Moteur : \(engine.engineName)"), detail: how.prefix(1).uppercased() + how.dropFirst() + "."))
        } else if engine == .quake4 && !OpenQ4.isSupported {
            items.append(.init(state: .missing, title: String(localized: "Moteur : openQ4"),
                               detail: String(localized: "Quake 4 ne se joue que sur un Mac Apple silicon : openQ4 n'existe pas pour Intel.")))
        } else if engine == .quake4 {
            items.append(.init(state: .missing, title: String(localized: "Moteur : openQ4, à télécharger"),
                               detail: String(localized: "Libre, \(OpenQ4.size). Borne le range dans votre dossier utilisateur."), fix: .offer(.needsOpenQ4)))
        } else if engine == .scummvm {
            items.append(.init(state: .missing, title: String(localized: "Moteur : ScummVM, à télécharger"),
                               detail: String(localized: "\(ScummVM.size), signé et notarisé par l'équipe de ScummVM. Borne le range dans votre dossier utilisateur."), fix: .offer(.needsScummVM)))
        } else if engine == .build {
            items.append(.init(state: .missing, title: String(localized: "Moteur : Raze, à télécharger"),
                               detail: String(localized: "\(Raze.size), signé et notarisé. Borne le range dans votre dossier utilisateur."), fix: .offer(.needsRaze)))
        } else {
            items.append(.init(state: .missing, title: String(localized: "Moteur introuvable"),
                               detail: String(localized: "Le moteur choisi dans Réglages → Jeux PC n'existe plus : choisissez-en un autre, ou « Intégré »."),
                               fix: .showSettings))
        }

        // Les fichiers du jeu.
        guard let data = m.dataPath else { return items }
        let dataURL = URL(fileURLWithPath: data)
        guard FileManager.default.fileExists(atPath: data) else {
            items.append(.init(state: .missing, title: String(localized: "Fichiers du jeu introuvables"),
                               detail: String(localized: "\(data)\nLe disque des jeux est-il branché ? Branchez-le, puis relisez les dossiers."),
                               fix: .rescan))
            return items
        }
        items.append(.init(state: .ok, title: String(localized: "Fichiers du jeu présents"), detail: data))

        switch engine {
        case .doom:
            if let pwad = m.modArg {
                let ok = FileManager.default.fileExists(atPath: pwad)
                items.append(.init(state: ok ? .ok : .missing, title: ok ? String(localized: "Mod présent") : String(localized: "Mod introuvable"),
                                   detail: String(localized: "\((pwad as NSString).lastPathComponent), joué avec \((data as NSString).lastPathComponent).")))
            }
            if (data as NSString).lastPathComponent.lowercased() == "strife1.wad",
               child(dataURL.deletingLastPathComponent(), "voices.wad") == nil {
                items.append(.init(state: .warning, title: String(localized: "Voix de Strife absentes"),
                                   detail: String(localized: "Copiez voices.wad à côté de strife1.wad : le jeu tourne sans, mais les personnages ne parlent pas.")))
            }

        case .quake:
            if let id1 = child(dataURL, "id1"), child(id1, "pak1.pak") == nil {
                items.append(.init(state: .warning, title: String(localized: "Version de démonstration"),
                                   detail: String(localized: "id1 n'a pas de pak1.pak : seul le premier épisode est jouable. Copiez pak1.pak depuis votre version complète.")))
            }

        case .quake3:
            items.append(patchItem(needed: Quake3Patch.isNeeded(base: dataURL), installed: Quake3Patch.isInstalled,
                                   name: "Quake III 1.32", fix: .needsQuake3Patch,
                                   why: String(localized: "Votre copie date d'avant la mise à jour 1.32 (pas de pak8.pk3 dans baseq3).")))

        case .doom3:
            let d3xp = m.gamePath.map { URL(fileURLWithPath: $0) }
            items.append(patchItem(needed: Doom3Patch.isNeeded(base: dataURL, d3xp: d3xp), installed: Doom3Patch.isInstalled,
                                   name: "Doom 3 1.3.1", fix: .needsDoom3Patch,
                                   why: d3xp == nil
                                       ? String(localized: "Votre copie vient du disque d'origine (pas de pak008.pk4).")
                                       : String(localized: "Votre copie vient du disque d'origine (pas de pak008.pk4 ou de d3xp/pak001.pk4).")))

        case .quake4:
            items.append(patchItem(needed: Quake4Patch.isNeeded(base: dataURL), installed: Quake4Patch.isInstalled,
                                   name: "Quake 4 1.4.2", fix: .needsQuake4Patch,
                                   why: String(localized: "Votre copie vient du DVD d'origine (q4base s'arrête avant pak022.pk4).")))
            if let q4 = child(dataURL, "q4base") {
                let files = (try? FileManager.default.contentsOfDirectory(atPath: q4.path)) ?? []
                if !files.contains(where: { $0.lowercased().range(of: #"^zpak_[a-z]+\.pk4$"#, options: .regularExpression) != nil }) {
                    items.append(.init(state: .warning, title: String(localized: "Voix absentes"),
                                       detail: String(localized: "Aucun zpak_<langue>.pk4 dans q4base : les personnages ne parlent pas. Copiez celui de votre version.")))
                }
            }

        case .rtcw:
            let want = ["pak0.pk3", "sp_pak1.pk3", "sp_pak2.pk3", "sp_pak3.pk3", "sp_pak4.pk3"]
            let missing = want.filter { child(dataURL, $0) == nil }
            if missing.isEmpty {
                items.append(.init(state: .ok, title: String(localized: "Fichiers de RTCW complets"), detail: want.joined(separator: ", ")))
            } else {
                items.append(.init(state: .warning, title: String(localized: "Fichiers de RTCW incomplets"),
                                   detail: String(localized: "Manquent : \(missing.joined(separator: ", ")). sp_pak3 et sp_pak4 viennent de la mise à jour 1.41 ; copiez-les depuis une version à jour (Steam, GOG).")))
            }

        case .wolf3d:
            let ext = (m.modArg ?? "wl6").uppercased()
            let own = ["VSWAP", "GAMEMAPS", "MAPHEAD"]
            let shared = ["AUDIOHED", "AUDIOT", "VGADICT", "VGAGRAPH", "VGAHEAD"]
            let sharedExt = ["SD2", "SD3"].contains(ext) ? "SOD" : ext
            let want = own.map { "\($0).\(ext)" } + shared.map { "\($0).\(sharedExt)" }
            let missing = want.filter { child(dataURL, $0) == nil }
            items.append(missing.isEmpty
                ? .init(state: .ok, title: String(localized: "Fichiers de données complets"), detail: want.joined(separator: ", "))
                : .init(state: .missing, title: String(localized: "Fichiers de données incomplets"),
                        detail: String(localized: "Manquent : \(missing.joined(separator: ", ")). Copiez-les depuis le dossier du jeu."), fix: .rescan))

        case .dos, .scummvm:
            if GameArchives.isArchive(data) {
                let size = ((try? FileManager.default.attributesOfItem(atPath: data)[.size]) as? Int).map {
                    ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
                } ?? "?"
                items.append(GameArchives.isExtracted(data)
                    ? .init(state: .ok, title: String(localized: "Archive décompressée"),
                            detail: String(localized: "Le jeu est dans votre dossier utilisateur : il se lance même sans le disque des jeux."))
                    : .init(state: .info, title: String(localized: "Archive à décompresser"),
                            detail: String(localized: "\((data as NSString).lastPathComponent) (\(size)) sera décompressée dans votre dossier utilisateur au premier lancement. L'archive elle-même n'est pas modifiée."),
                            fix: .offer(.needsExtraction)))
            }
            if engine == .dos, let note = DOSGames.notes[m.name.replacingOccurrences(of: "dos:", with: "")] {
                items.append(.init(state: .info, title: String(localized: "Premier lancement"), detail: note))
            }
            if engine == .dos, let k = DOSGames.known(for: m) {
                items.append(.init(state: .info, title: k.run.count > 1 ? String(localized: "Commandes") : String(localized: "Commande"),
                                   detail: k.run.count > 1
                                       ? String(localized: "\(k.run.joined(separator: " · ")), lancées par DOSBox Staging dans le dossier du jeu.")
                                       : String(localized: "\(k.run.joined(separator: " · ")), lancée par DOSBox Staging dans le dossier du jeu.")))
            }

        default:
            break
        }

        items.append(.init(state: .info, title: String(localized: "Sauvegardes et réglages"),
                           detail: String(localized: "Dans votre dossier utilisateur, jamais à côté des fichiers du jeu."), fix: .revealUserData))
        return items
    }

    private static func patchItem(needed: Bool, installed: Bool, name: String, fix: EngineLaunchError, why: String) -> DiagnosticItem {
        if !needed { return .init(state: .ok, title: String(localized: "Version à jour"), detail: String(localized: "Votre copie contient déjà la mise à jour \(name).")) }
        if installed {
            return .init(state: .ok, title: String(localized: "Mise à jour \(name) installée"),
                         detail: String(localized: "\(why) Les fichiers de la mise à jour sont dans votre dossier utilisateur."))
        }
        return .init(state: .missing, title: String(localized: "Mise à jour \(name) nécessaire"),
                     detail: String(localized: "\(why) Le moteur moderne en a besoin. Borne télécharge la mise à jour officielle d'id Software une fois sa licence acceptée."),
                     fix: .offer(fix))
    }

    private static func child(_ dir: URL, _ name: String) -> URL? {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return items.first { $0.lowercased() == name.lowercased() }.map { dir.appendingPathComponent($0) }
    }

    // MARK: Arcade (MAME : quelques secondes, hors du fil principal)

    struct ArcadeFacts: Sendable {
        var sets: [String] = []
        var samples: [String] = []
        var located: [String: String] = [:]      // ensemble → chemin trouvé
        var samplesFound: Set<String> = []
        var verdict: AuditResult?
        var problems: [(file: String, kind: String, owner: String?, noGoodDump: Bool)] = []
        var notFound = false
    }

    static func arcadeFacts(_ name: String) throws -> ArcadeFacts {
        var f = ArcadeFacts()
        let req = try Installer.requirements(of: name)
        f.sets = req.sets
        f.samples = req.samples
        for set in req.sets {
            if let url = Installer.locate(set, in: Prefs.searchROMPaths).first { f.located[set] = url.path }
        }
        let samplePaths = [Prefs.localSamples.path, Prefs.mediaRoot.appendingPathComponent("samples").path]
        for s in req.samples where !Installer.locate(s, in: samplePaths).isEmpty { f.samplesFound.insert(s) }
        try Task.checkCancellation()

        let out = try MAMERunner.run(Prefs.pathArguments + ["-verifyroms", name])
        f.verdict = MAMERunner.parseAudit(out)[name]
        f.notFound = out.contains("romset \"\(name)\" not found")
        for line in out.split(separator: "\n") {
            // « name : file (123 bytes) - NOT FOUND (owner) » ; les disques n'ont pas de taille.
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, parts[0] == name, let dash = parts[1].range(of: " - ") else { continue }
            var file = String(parts[1][..<dash.lowerBound])
            if let paren = file.range(of: " (") { file = String(file[..<paren.lowerBound]) }
            var status = String(parts[1][dash.upperBound...])
            var owner: String?
            if let open = status.lastIndex(of: "("), status.hasSuffix(")") {
                owner = String(status[status.index(after: open)..<status.index(before: status.endIndex)])
                status = String(status[..<open]).trimmingCharacters(in: .whitespaces)
            }
            let noGood = status.contains("NO GOOD DUMP KNOWN")
            let kind = status.replacingOccurrences(of: " - NO GOOD DUMP KNOWN", with: "")
            f.problems.append((file, kind, owner, noGood))
        }
        return f
    }

    static func arcadeItems(_ m: Machine, _ f: ArcadeFacts, machines: [String: Machine], romFoldersMissing: Bool) -> [DiagnosticItem] {
        var items: [DiagnosticItem] = []
        if !m.needsFiles {
            return [.init(state: .ok, title: String(localized: "Aucune ROM requise"), detail: String(localized: "Ce jeu se lance sans fichier."))]
        }

        // Rôle de chaque ensemble : le jeu, son original, son BIOS, ou un périphérique.
        var chain: [String] = []
        var cursor = m.romOf
        while let c = cursor, !chain.contains(c) {
            chain.append(c)
            cursor = machines[c]?.romOf
        }
        func role(_ set: String) -> String {
            if set == m.name { return String(localized: "Le jeu") }
            if set == m.cloneOf { return String(localized: "L'original") }
            if chain.contains(set) { return String(localized: "Le BIOS") }
            return String(localized: "Un périphérique")
        }
        for set in f.sets {
            let label = String(localized: "\(role(set)) : \(set).zip")
            if let path = f.located[set] {
                let local = path.hasPrefix(Prefs.localROMs.path)
                items.append(.init(state: .ok, title: label,
                                   detail: local ? String(localized: "Copie sur ce Mac.") : (path as NSString).deletingLastPathComponent))
            } else if set == m.name, let p = m.cloneOf, f.located[p] != nil {
                items.append(.init(state: .ok, title: String(localized: "\(label) — dans l'original"),
                                   detail: String(localized: "Collection fusionnée : les fichiers du clone sont dans \(p).zip.")))
            } else {
                let what = machines[set]?.description ?? set
                var how = String(localized: "Ajoutez \(set).zip (\(what)) à un dossier ROM, puis relisez les dossiers.")
                if romFoldersMissing { how += " " + String(localized: "Un dossier ROM est introuvable : le disque des jeux est-il branché ?") }
                items.append(.init(state: .missing, title: String(localized: "\(label) absent"), detail: how, fix: .rescan))
            }
        }

        for s in f.samples {
            items.append(f.samplesFound.contains(s)
                ? .init(state: .ok, title: String(localized: "Sons : \(s).zip"), detail: String(localized: "Échantillons sonores présents."))
                : .init(state: .warning, title: String(localized: "Sons : \(s).zip absent"),
                        detail: String(localized: "Le jeu tourne, sans certains bruitages. Placez \(s).zip dans le dossier samples, à côté du dossier roms.")))
        }

        // Verdict de MAME, fichier par fichier.
        let real = f.problems.filter { !$0.noGoodDump }
        let unknown = f.problems.filter(\.noGoodDump)
        switch f.verdict {
        case .good?:
            items.append(.init(state: .ok, title: String(localized: "Vérification MAME : complet"), detail: String(localized: "Tous les fichiers sont présents et justes."), fix: .verify))
        case .bestAvailable?:
            items.append(.init(state: .ok, title: String(localized: "Vérification MAME : meilleur disponible"),
                               detail: String(localized: "Jouable. \(unknown.count) fichier(s) n'ont jamais été copiés correctement par personne : leur absence n'est pas de votre fait."),
                               fix: .verify))
        case .bad?:
            let missing = real.filter { $0.kind.contains("NOT FOUND") }
            let wrong = real.filter { !$0.kind.contains("NOT FOUND") }
            var lines: [String] = []
            for owner in Set(missing.compactMap(\.owner)).sorted() {
                let count = missing.filter { $0.owner == owner }.count
                lines.append(f.located[owner] != nil
                    ? String(localized: "\(owner).zip est là, mais il lui manque \(count) fichier(s) : remplacez-le par l'ensemble de MAME 0.289.")
                    : String(localized: "\(count) fichier(s) attendus dans \(owner).zip, absent : ajoutez-le à un dossier ROM."))
            }
            let own = missing.filter { $0.owner == nil }
            if !own.isEmpty {
                lines.append(String(localized: "\(own.count) fichier(s) absents de \(m.name).zip (\(own.prefix(3).map(\.file).joined(separator: ", "))\(own.count > 3 ? "…" : "")) : remplacez-le par l'ensemble de MAME 0.289."))
            }
            if !wrong.isEmpty {
                lines.append(String(localized: "\(wrong.count) fichier(s) d'une autre version (\(wrong.prefix(3).map(\.file).joined(separator: ", "))\(wrong.count > 3 ? "…" : ""))."))
            }
            lines.append(String(localized: "Les ensembles d'une autre version de MAME ne correspondent souvent pas : ceux de Borne doivent être faits pour MAME 0.289."))
            items.append(.init(state: .missing, title: String(localized: "Vérification MAME : incomplet"), detail: lines.joined(separator: "\n"), fix: .verify))
        case nil:
            items.append(f.notFound
                ? .init(state: .missing, title: String(localized: "Vérification MAME : aucun fichier trouvé"),
                        detail: String(localized: "Ni le jeu ni son original ne sont dans les dossiers ROM."), fix: .rescan)
                : .init(state: .info, title: String(localized: "Vérification MAME : sans réponse"), fix: .verify))
        }
        return items
    }
}
