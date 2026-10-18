import AppKit
import Foundation
import Observation

/// Les dossiers de gauche, comme dans MAMEUI.
enum Folder: Hashable {
    case all, available, unavailable, favorites, local
    case parents, clones, working, notWorking
    case bios, mechanical, horizontal, vertical, savestate
    case manufacturer(String), year(String), source(String), cpu(String)
    /// Ligne « Regrouper par » : ouvre un sélecteur, ne filtre pas.
    case chooser(String)

    static let main: [Folder] = [.all, .available, .unavailable, .favorites, .local]
    static let traits: [Folder] = [.parents, .clones, .working, .notWorking,
                                   .bios, .mechanical, .horizontal, .vertical, .savestate]

    var title: String {
        switch self {
        case .all: "Tous les jeux"
        case .available: "Disponibles"
        case .unavailable: "Non disponibles"
        case .favorites: "Favoris"
        case .local: "Sur ce Mac"
        case .parents: "Originaux"
        case .clones: "Clones"
        case .working: "Fonctionnels"
        case .notWorking: "Non fonctionnels"
        case .bios: "BIOS"
        case .mechanical: "Mécaniques"
        case .horizontal: "Écran horizontal"
        case .vertical: "Écran vertical"
        case .savestate: "Sauvegarde d'état"
        case .manufacturer(let s), .year(let s), .source(let s), .cpu(let s), .chooser(let s): s
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.3x3"
        case .available: "checkmark.circle"
        case .unavailable: "xmark.circle"
        case .favorites: "star"
        case .local: "laptopcomputer"
        case .parents: "person"
        case .clones: "person.2"
        case .working: "hand.thumbsup"
        case .notWorking: "hand.thumbsdown"
        case .bios: "cpu"
        case .mechanical: "gearshape.2"
        case .horizontal: "rectangle"
        case .vertical: "rectangle.portrait"
        case .savestate: "square.and.arrow.down"
        case .manufacturer: "building.2"
        case .year: "calendar"
        case .source: "doc.text"
        case .cpu: "memorychip"
        case .chooser: "line.3.horizontal.decrease"
        }
    }
}

/// Ce dont le filtrage a besoin, figé au moment de la demande.
private struct FilterContext {
    let available: Set<String>
    let favorites: Set<String>
    let local: Set<String>

    func matches(_ m: Machine, _ f: Folder) -> Bool {
        switch f {
        case .all: true
        case .available: available.contains(m.name)
        case .unavailable: !available.contains(m.name)
        case .favorites: favorites.contains(m.name)
        case .local: local.contains(m.name)
        case .parents: !m.isClone
        case .clones: m.isClone
        case .working: m.status == "good" || m.status == "imperfect"
        case .notWorking: m.status == "preliminary"
        case .bios: m.isBIOS
        case .mechanical: m.isMechanical
        case .horizontal: !m.screen.isEmpty && !m.isVertical
        case .vertical: m.isVertical
        case .savestate: m.savestate
        case .manufacturer(let s): m.manufacturer == s
        case .year(let s): m.year == s
        case .source(let s): m.sourcefile == s
        case .cpu(let s): m.cpus.contains(s)
        case .chooser: true
        }
    }
}

private struct ViewInput {
    var all: [Machine]
    var sorted: [Machine]?
    var sortOrder: [KeyPathComparator<Machine>]
    var folder: Folder
    var search: String
    var present: Set<String>
    var audit: [String: AuditResult]?
    var favorites: Set<String>
    var local: Set<String>
}

private struct ViewOutput {
    var sorted: [Machine]
    var displayed: [Machine]
    var available: Set<String>
    var counts: [Folder: Int]
}

@MainActor @Observable
final class Catalog {
    enum Phase: Equatable {
        case idle
        case loading(String)
        case failed(String)
    }

    /// Travail de fond en cours (audit, installation), interruptible.
    struct Job: Equatable {
        var title: String
        var progress: Double?
    }

    /// Installation préparée, en attente de confirmation.
    struct InstallProposal: Identifiable {
        let id = UUID()
        let plan: InstallPlan
        let title: String
        let message: String
        let fits: Bool
    }

    private(set) var phase: Phase = .idle
    private(set) var job: Job?
    private(set) var version = ""
    private(set) var machines: [String: Machine] = [:]
    private var all: [Machine] = []
    @ObservationIgnored private var sortedCache: [Machine]?
    private(set) var displayed: [Machine] = []
    /// Change à chaque résultat de filtrage : le tableau se recharge alors.
    private(set) var tableGeneration = 0
    private(set) var available: Set<String> = []
    private(set) var counts: [Folder: Int] = [:]
    private(set) var manufacturers: [(String, Int)] = []
    private(set) var years: [(String, Int)] = []
    private(set) var sources: [(String, Int)] = []
    private(set) var cpus: [(String, Int)] = []
    private(set) var running: String?
    /// Vrai pendant qu'un filtrage tourne en arrière-plan.
    private(set) var refreshing = false
    /// Dossiers ROM du disque des jeux introuvables (disque débranché ?).
    private(set) var missingROMPaths: [String] = []
    var notice: (title: String, message: String)?
    /// Change quand des réglages de jeu sont effacés, pour rafraîchir la fiche.
    private(set) var settingsGeneration = 0
    /// Ce qui a été compris du dernier dossier des jeux choisi.
    var gamesFolderNote: String?
    var proposal: InstallProposal?

    // La liste et le tableau réécrivent leur sélection à chaque rendu, même
    // inchangée : ne réagir qu'aux vrais changements, sinon boucle sans fin.
    var folder: Folder? = .available { didSet { if folder != oldValue { refreshView() } } }
    var search = "" { didSet { if search != oldValue { refreshView(delay: .milliseconds(150)) } } }
    var selection: String?
    var sortOrder = [KeyPathComparator(\Machine.description, comparator: .localizedStandard)] {
        didSet { if sortOrder != oldValue { refreshView(resort: true) } }
    }

    private(set) var favorites: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(favorites), forKey: "favorites")
            refreshView()
        }
    }

    /// Jeux installés sur le Mac → fichiers copiés pour eux.
    private(set) var installed: [String: [String]] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(installed) {
                try? data.write(to: Self.manifestURL, options: .atomic)
            }
            refreshView()
        }
    }

    private var present: Set<String> = []
    private var audit: [String: AuditResult]?
    @ObservationIgnored private var viewTask: Task<Void, Never>?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var jobTask: Task<Void, Never>?

    init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])
        // Test : ouvrir sur « Tous les jeux » (open --args -startFolderAll YES).
        if UserDefaults.standard.bool(forKey: "startFolderAll") { folder = .all }
        if let data = try? Data(contentsOf: Self.manifestURL),
           let m = try? JSONDecoder().decode([String: [String]].self, from: data) {
            installed = m
        }
    }

    var selected: Machine? { selection.flatMap { machines[$0] } }
    func auditResult(_ name: String) -> AuditResult? { audit?[name] }
    var hasAudit: Bool { audit != nil }
    func isLocal(_ name: String) -> Bool { installed[name] != nil }

    nonisolated private static var manifestURL: URL { Prefs.supportDirectory.appendingPathComponent("installes.json") }
    nonisolated private static var auditURL: URL { Prefs.supportDirectory.appendingPathComponent("audit.json") }

    // MARK: Chargement

    func load(forceRefresh: Bool = false) async {
        phase = .loading("Interrogation de mame…")
        do {
            let version = try await Task.detached { try MAMERunner.version() }.value
            self.version = version
            let cache = Prefs.supportDirectory.appendingPathComponent("catalogue-\(version).json")
            let list: [Machine] = try await Task.detached {
                if !forceRefresh, let data = try? Data(contentsOf: cache),
                   let decoded = try? JSONDecoder().decode([Machine].self, from: data) {
                    return decoded
                }
                let list = try MAMERunner.listXML { n in
                    Task { @MainActor in self.phase = .loading("Lecture des machines : \(n)…") }
                }
                try JSONEncoder().encode(list).write(to: cache, options: .atomic)
                return list
            }.value
            all = list
            machines = Dictionary(list.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
            audit = await Task.detached {
                (try? Data(contentsOf: Self.auditURL))
                    .flatMap { try? JSONDecoder().decode([String: AuditResult].self, from: $0) }
            }.value
            buildGroups()
            phase = .idle
            refreshView(resort: true)
            scanROMs()
            // Captures du site : open --args -selectGame gridlee
            if let g = UserDefaults.standard.string(forKey: "selectGame"), machines[g] != nil {
                selection = g
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func buildGroups() {
        func tally(_ key: (Machine) -> [String]) -> [(String, Int)] {
            var c: [String: Int] = [:]
            for m in all { for k in key(m) where !k.isEmpty { c[k, default: 0] += 1 } }
            return c.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
                .map { ($0.key, $0.value) }
        }
        manufacturers = tally { [$0.manufacturer] }
        years = tally { [$0.year] }
        sources = tally { [$0.sourcefile] }
        cpus = tally { $0.cpus }
    }

    // MARK: Affichage (toujours hors du fil principal, la dernière demande gagne)

    private func refreshView(resort: Bool = false, delay: Duration = .zero) {
        if resort { sortedCache = nil }
        guard !all.isEmpty else { return }
        viewTask?.cancel()
        let input = ViewInput(all: all, sorted: sortedCache, sortOrder: sortOrder,
                              folder: folder ?? .all, search: search, present: present,
                              audit: audit, favorites: favorites, local: Set(installed.keys))
        if !refreshing { refreshing = true }
        viewTask = Task {
            if delay > .zero {
                try? await Task.sleep(for: delay)
                if Task.isCancelled { return }
            }
            guard let out = await Self.compute(input), !Task.isCancelled else { return }
            sortedCache = out.sorted
            if out.displayed != displayed { displayed = out.displayed }
            if out.available != available { available = out.available }
            if out.counts != counts { counts = out.counts }
            tableGeneration += 1
            refreshing = false
        }
    }

    nonisolated private static func compute(_ i: ViewInput) async -> ViewOutput? {
        let sorted = i.sorted ?? i.all.sorted(using: i.sortOrder)
        if Task.isCancelled { return nil }

        var available = Set<String>(minimumCapacity: 4096)
        for m in i.all where isAvailable(m, present: i.present, audit: i.audit) {
            available.insert(m.name)
        }
        if Task.isCancelled { return nil }

        let ctx = FilterContext(available: available, favorites: i.favorites, local: i.local)
        var counts: [Folder: Int] = [:]
        for f in Folder.main + Folder.traits {
            counts[f] = i.all.reduce(0) { $0 + (ctx.matches($1, f) ? 1 : 0) }
            if Task.isCancelled { return nil }
        }

        let q = i.search.trimmingCharacters(in: .whitespaces)
        var displayed: [Machine] = []
        for (k, m) in sorted.enumerated() {
            if k & 4095 == 0 && Task.isCancelled { return nil }
            guard ctx.matches(m, i.folder) else { continue }
            if q.isEmpty
                || m.description.localizedCaseInsensitiveContains(q)
                || m.name.localizedCaseInsensitiveContains(q)
                || m.manufacturer.localizedCaseInsensitiveContains(q) {
                displayed.append(m)
            }
        }
        return ViewOutput(sorted: sorted, displayed: displayed, available: available, counts: counts)
    }

    nonisolated private static func isAvailable(_ m: Machine, present: Set<String>,
                                                audit: [String: AuditResult]?) -> Bool {
        if !m.needsFiles { return true }
        // Le verdict de l'audit prime ; sans verdict (pas d'audit, ou ensemble
        // ajouté depuis), la présence du fichier suffit.
        if let r = audit?[m.name] { return r.isPlayable }
        if present.contains(m.name) { return true }
        // Ensembles fusionnés : le clone est dans le zip de l'original.
        if let p = m.cloneOf { return present.contains(p) }
        return false
    }

    // MARK: Dossiers ROM

    /// Relit le contenu des dossiers ROM, sans bloquer l'interface.
    func scanROMs() {
        scanTask?.cancel()
        let paths = Prefs.searchROMPaths
        scanTask = Task {
            guard let (names, missing) = await Self.scan(paths), !Task.isCancelled else { return }
            present = names
            let external = missing.filter { $0 != Prefs.localROMs.path }
            if external != missingROMPaths { missingROMPaths = external }
            refreshView()
        }
    }

    nonisolated private static func scan(_ paths: [String]) async -> (Set<String>, [String])? {
        let fm = FileManager.default
        var names = Set<String>()
        var missing: [String] = []
        for path in paths {
            if Task.isCancelled { return nil }
            guard let entries = try? fm.contentsOfDirectory(atPath: path) else {
                missing.append(path)
                continue
            }
            for entry in entries {
                let ext = (entry as NSString).pathExtension.lowercased()
                if ext == "zip" || ext == "7z" || ext.isEmpty {
                    names.insert((entry as NSString).deletingPathExtension)
                }
            }
        }
        return (names, missing)
    }

    // MARK: Travaux de fond

    /// Un seul travail à la fois : en lancer un interrompt le précédent.
    private func startJob(_ title: String, _ work: @escaping @MainActor () async -> Void) {
        jobTask?.cancel()
        let previous = jobTask
        job = Job(title: title)
        jobTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await work()
            if !Task.isCancelled { job = nil }
        }
    }

    func cancelJob() {
        jobTask?.cancel()
        jobTask = nil
        job = nil
    }

    private func setProgress(_ title: String, _ progress: Double?) {
        guard job != nil else { return }
        job = Job(title: title, progress: progress)
    }

    /// Audit par mame -verifyroms, limité aux sets présents ; les verdicts
    /// s'affichent au fur et à mesure.
    func verifyROMs() {
        let candidates = all.filter { m in
            m.needsFiles && (present.contains(m.name) || m.cloneOf.map(present.contains) == true)
        }.map(\.name)
        guard !candidates.isEmpty else {
            notice = ("Aucun set à vérifier", "Aucun fichier de ROM n'a été trouvé dans les dossiers ROM.")
            return
        }
        let args = Prefs.pathArguments + ["-verifyroms"] + candidates
        let total = Double(candidates.count)
        startJob("Vérification des ROM…") { [weak self] in
            guard let self else { return }
            var found: [String: AuditResult] = [:]
            var pending: [String: AuditResult] = [:]
            var last = Date()
            do {
                try await MAMERunner.stream(args) { line in
                    guard let (name, r) = MAMERunner.parseAuditLine(line) else { return }
                    found[name] = r
                    pending[name] = r
                    if Date().timeIntervalSince(last) > 0.5 {
                        last = Date()
                        let batch = pending
                        pending = [:]
                        let done = Double(found.count)
                        Task { @MainActor in
                            self.audit = (self.audit ?? [:]).merging(batch) { _, new in new }
                            self.setProgress("Vérification des ROM…", min(1, done / total))
                            self.refreshView()
                        }
                    }
                }
                // Audit complet : il remplace l'ancien.
                audit = found
            } catch {
                // Interrompu : on garde ce qui a été vérifié.
                audit = (audit ?? [:]).merging(found) { _, new in new }
            }
            if let audit, let data = try? JSONEncoder().encode(audit) {
                try? data.write(to: Self.auditURL, options: .atomic)
            }
            refreshView()
        }
    }

    // MARK: Installation sur le Mac

    /// Prépare la copie locale des jeux et demande confirmation avec la taille.
    func proposeInstall(_ names: [String]) {
        let games = names.filter { machines[$0] != nil && available.contains($0) }
        guard !games.isEmpty else {
            notice = ("Rien à installer", "Ces jeux ne sont pas disponibles sur le disque des jeux.")
            return
        }
        let romPaths = Prefs.romPaths
        let samplePaths = [Prefs.mediaRoot.appendingPathComponent("samples").path]
        let root = Prefs.userDataRoot
        let total = Double(games.count)
        startJob("Préparation de l'installation…") { [weak self] in
            guard let self else { return }
            do {
                let plan = try await Task.detached {
                    try Installer.plan(games: games, romPaths: romPaths, samplePaths: samplePaths,
                                       userRoot: root) { i in
                        Task { @MainActor in self.setProgress("Préparation de l'installation…", Double(i) / total) }
                    }
                }.value
                if Task.isCancelled { return }
                let free = (try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                    .volumeAvailableCapacityForImportantUsage) ?? 0
                // Garder de la marge : le disque du Mac ne doit pas finir plein.
                let margin: Int64 = 5 << 30
                let fits = plan.bytes + margin < free
                let size = ByteCountFormatter.string(fromByteCount: plan.bytes, countStyle: .file)
                let freeText = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
                let what = games.count == 1
                    ? (machines[games[0]]?.description ?? games[0])
                    : "\(games.count) jeux"
                proposal = InstallProposal(
                    plan: plan,
                    title: "Installer \(what) sur ce Mac ?",
                    message: fits
                        ? "\(size) à copier (\(plan.items.count) fichiers), \(freeText) libres. Le jeu se lancera ensuite sans le disque des jeux."
                        : "\(size) à copier, mais seulement \(freeText) libres sur ce Mac (5 Go de marge gardés).",
                    fits: fits)
            } catch is CancellationError {
            } catch {
                notice = ("Installation impossible", error.localizedDescription)
            }
        }
    }

    func install(_ plan: InstallPlan) {
        proposal = nil
        let root = Prefs.userDataRoot
        let total = max(1, plan.bytes)
        startJob("Copie sur ce Mac…") { [weak self] in
            guard let self else { return }
            let task = Task.detached { () throws -> [String: AuditResult?] in
                var done: Int64 = 0
                var last = Date()
                try Installer.copy(plan, to: root) { n in
                    done += n
                    if Date().timeIntervalSince(last) > 0.25 {
                        last = Date()
                        let p = Double(done) / Double(total)
                        Task { @MainActor in self.setProgress("Copie sur ce Mac…", p) }
                    }
                }
                var results: [String: AuditResult?] = [:]
                for g in plan.games {
                    try Task.checkCancellation()
                    results[g] = try Installer.verifyLocal(g, romRoot: root.appendingPathComponent("roms"))
                }
                return results
            }
            do {
                let results = try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
                var m = installed
                var incomplete: [String] = []
                for g in plan.games {
                    // Gardé même incomplet : les fichiers copiés servent quand même.
                    m[g] = plan.perGame[g] ?? []
                    if results[g].flatMap({ $0 })?.isPlayable != true { incomplete.append(g) }
                }
                installed = m
                scanROMs()
                if !incomplete.isEmpty {
                    notice = ("Copie incomplète",
                              "MAME ne trouve pas tout en local pour : \(incomplete.joined(separator: ", ")). Ces jeux auront encore besoin du disque des jeux.")
                }
            } catch {
                if !(error is CancellationError) {
                    notice = ("Copie interrompue", error.localizedDescription)
                }
            }
        }
    }

    func uninstall(_ name: String) {
        let root = Prefs.userDataRoot
        let manifest = installed
        Task {
            installed = await Task.detached { Installer.remove(name, from: manifest, root: root) }.value
            scanROMs()
        }
    }

    // MARK: Actions

    func toggleFavorite(_ name: String) {
        if favorites.contains(name) { favorites.remove(name) } else { favorites.insert(name) }
    }

    func launch(_ name: String) {
        guard running == nil else { return }
        do { try Prefs.prepareUserData() } catch {
            notice = ("MAME n'a pas pu lancer le jeu", error.localizedDescription)
            return
        }
        var args = [name, "-skip_gameinfo"] + Prefs.pathArguments + Prefs.displayArguments
        if Prefs.windowed { args.append("-window") }
        args += Prefs.extraArgs

        let log = FileManager.default.temporaryDirectory.appendingPathComponent("borne-mame.log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let p = Process()
        p.executableURL = Prefs.mameURL
        p.arguments = args
        p.currentDirectoryURL = Prefs.userDataRoot
        if let h = try? FileHandle(forWritingTo: log) {
            p.standardOutput = h
            p.standardError = h
        }
        p.terminationHandler = { proc in
            let status = proc.terminationStatus
            let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
            Task { @MainActor in
                self.running = nil
                KeyHUD.shared.hide()
                if status != 0 {
                    let tail = text.split(separator: "\n").suffix(12).joined(separator: "\n")
                    self.notice = ("MAME n'a pas pu lancer le jeu",
                                   tail.isEmpty ? "mame s'est arrêté (code \(status))." : tail)
                }
            }
        }
        do {
            try p.run()
            running = name
            handOver(to: p.processIdentifier, machine: machines[name])
        } catch {
            notice = ("MAME n'a pas pu lancer le jeu", error.localizedDescription)
        }
    }

    /// Donne le clavier à MAME dès que sa fenêtre existe (sinon Borne garde
    /// le focus et les touches n'arrivent pas au jeu), puis montre les touches.
    private func handOver(to pid: pid_t, machine: Machine?) {
        Task {
            for _ in 0..<80 {
                try? await Task.sleep(for: .milliseconds(100))
                guard running != nil else { return }
                guard let app = NSRunningApplication(processIdentifier: pid),
                      Self.hasWindow(pid) else { continue }
                NSApp.yieldActivation(to: app)
                app.activate(from: .current, options: [])
                if let machine { KeyHUD.shared.show(for: machine) }
                return
            }
        }
    }

    private static func hasWindow(_ pid: pid_t) -> Bool {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return list.contains { w in
            (w[kCGWindowOwnerPID as String] as? pid_t) == pid
                && (w[kCGWindowLayer as String] as? Int) == 0
                && ((w[kCGWindowBounds as String] as? [String: Double])?["Height"] ?? 0) > 100
        }
    }

    /// Réglages que MAME a enregistrés pour ce jeu (touches, volume,
    /// position de l'écran…). Les sauvegardes et scores sont ailleurs.
    func settingsFile(_ name: String) -> URL {
        Prefs.userDataRoot.appendingPathComponent("cfg/\(name).cfg")
    }

    func hasSettings(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: settingsFile(name).path)
    }

    /// Le réglage du jeu contient-il des choix d'affichage (position,
    /// échelle, vue de l'écran) ?
    func hasDisplaySettings(_ name: String) -> Bool {
        guard let text = try? String(contentsOf: settingsFile(name), encoding: .utf8) else { return false }
        return text.contains("<video>")
    }

    /// Retire seulement la partie <video> du réglage : touches, volume et
    /// compteurs restent.
    func resetDisplay(_ name: String) {
        guard running != name else {
            notice = ("Jeu en cours", "Quittez le jeu (Échap) avant de réinitialiser son affichage.")
            return
        }
        let url = settingsFile(name)
        do {
            let doc = try XMLDocument(contentsOf: url, options: [.nodePreserveWhitespace])
            for node in try doc.nodes(forXPath: "//system/video") {
                node.detach()
            }
            try doc.xmlData(options: [.nodePrettyPrint]).write(to: url, options: .atomic)
            settingsGeneration += 1
        } catch {
            notice = ("Réinitialisation impossible", error.localizedDescription)
        }
    }

    /// Met les réglages du jeu à la Corbeille : MAME repart des valeurs d'origine.
    func resetSettings(_ name: String) {
        guard running != name else {
            notice = ("Jeu en cours", "Quittez le jeu (Échap) avant de réinitialiser ses réglages.")
            return
        }
        do {
            try FileManager.default.trashItem(at: settingsFile(name), resultingItemURL: nil)
            settingsGeneration += 1
        } catch {
            notice = ("Réinitialisation impossible", error.localizedDescription)
        }
    }

    func revealUserData() {
        try? Prefs.prepareUserData()
        NSWorkspace.shared.open(Prefs.userDataRoot)
    }

    func revealROMFolder() {
        // Pas de création de dossier ici : le disque des jeux n'est jamais modifié.
        if let first = Prefs.romPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            NSWorkspace.shared.open(URL(fileURLWithPath: first))
        }
    }
}
