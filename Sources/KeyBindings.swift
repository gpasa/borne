import AppKit
import SwiftUI

/// Touches des jeux PC, choisies une fois dans Borne pour tous les moteurs
/// de la famille id/ZDoom (Doom, Quake I à 4, Doom 3, RTCW, jeux Build).
/// Borne les écrit dans le fichier qu'il fait exécuter au moteur à chaque
/// lancement ; les choix faits dans le menu du jeu valent pour les autres touches.
enum KeyAction: String, CaseIterable, Identifiable {
    case forward, back, left, right, fire, jump, crouch, use
    // Sans touche imposée par Borne : liées seulement si l'utilisateur en choisit une
    // (utile quand la touche d'origine demande Maj sur son clavier).
    case nextWeapon, prevWeapon, run, quickSave, quickLoad, map, console, sizeUp, sizeDown, screenshot

    var id: String { rawValue }

    static let main: [KeyAction] = [.forward, .back, .left, .right, .fire, .jump, .crouch, .use]
    static let others: [KeyAction] = [.nextWeapon, .prevWeapon, .run, .quickSave, .quickLoad, .map, .console, .sizeUp, .sizeDown, .screenshot]

    var title: String {
        switch self {
        case .forward: "Avancer"
        case .back: "Reculer"
        case .left: "Pas à gauche"
        case .right: "Pas à droite"
        case .fire: "Tirer (en plus du clic)"
        case .jump: "Sauter"
        case .crouch: "S'accroupir"
        case .use: "Utiliser, ouvrir"
        case .nextWeapon: "Arme suivante"
        case .prevWeapon: "Arme précédente"
        case .run: "Courir (maintenir)"
        case .quickSave: "Sauvegarde rapide"
        case .quickLoad: "Chargement rapide"
        case .map: "Carte"
        case .console: "Console"
        case .sizeUp: "Agrandir l'image"
        case .sizeDown: "Réduire l'image"
        case .screenshot: "Capture d'écran"
        }
    }

    var prefKey: String { "key.\(rawValue)" }
}

enum KeyBindings {
    /// Commande du moteur pour chaque action ; absente si le jeu ne l'a pas.
    static func command(_ a: KeyAction, _ e: Engine) -> String? {
        let idTech4 = e == .doom3 || e == .quake4
        let zdoom = e == .doom || e == .build
        switch a {
        case .forward: return idTech4 ? "_forward" : "+forward"
        case .back: return idTech4 ? "_back" : "+back"
        case .left: return idTech4 ? "_moveLeft" : "+moveleft"
        case .right: return idTech4 ? "_moveRight" : "+moveright"
        case .fire: return idTech4 ? "_attack" : "+attack"
        case .jump:
            switch e {
            case .doom: return nil                     // Doom d'origine : pas de saut
            case .quake, .build: return "+jump"
            case .doom3, .quake4: return "_moveUp"
            default: return "+moveup"
            }
        case .crouch:
            switch e {
            case .doom, .quake: return nil
            case .build: return "+crouch"
            case .doom3, .quake4: return "_moveDown"
            default: return "+movedown"
            }
        case .use:
            switch e {
            case .doom, .build: return "+use"
            case .rtcw: return "+activate"
            default: return nil
            }
        case .nextWeapon: return e == .quake ? "impulse 10" : idTech4 ? "_impulse14" : "weapnext"
        case .prevWeapon: return e == .quake ? "impulse 12" : idTech4 ? "_impulse15" : "weapprev"
        case .run: return e == .build ? "+run" : idTech4 ? "_speed" : "+speed"
        case .quickSave:
            return zdoom ? "quicksave" : (e == .quake || e == .quake2) ? "save quick" : idTech4 ? "savegame quick" : nil
        case .quickLoad:
            return zdoom ? "quickload" : (e == .quake || e == .quake2) ? "load quick" : idTech4 ? "loadgame quick" : nil
        case .map: return zdoom ? "togglemap" : nil
        case .console: return idTech4 ? nil : "toggleconsole"
        case .sizeUp: return (zdoom || e == .quake || e == .quake2) ? "sizeup" : nil
        case .sizeDown: return (zdoom || e == .quake || e == .quake2) ? "sizedown" : nil
        case .screenshot: return "screenshot"
        }
    }

    static let supported: Set<Engine> = [.doom, .quake, .quake2, .quake3, .rtcw, .doom3, .quake4, .build]

    /// Touche d'origine du moteur, que Borne libère quand l'action change de
    /// touche ; nil pour les actions que Borne ne lie pas d'office.
    static func engineDefault(_ a: KeyAction, _ e: Engine) -> String? {
        switch a {
        case .forward: "w"
        case .back: "s"
        case .left: "a"
        case .right: "d"
        case .fire: "x"
        case .jump: e == .build ? "e" : "space"
        case .crouch: "c"
        case .use: e == .build ? "space" : e == .rtcw ? "f" : "e"
        default: nil
        }
    }

    static func chosen(_ a: KeyAction) -> String? { UserDefaults.standard.string(forKey: a.prefKey) }

    /// Touche choisie, ou celle d'origine.
    static func key(_ a: KeyAction, _ e: Engine) -> String {
        chosen(a) ?? engineDefault(a, e) ?? ""
    }

    /// Lignes à exécuter par le moteur.
    static func script(for e: Engine) -> String {
        var unbind: [String] = []
        var bind: [String] = []
        for a in KeyAction.allCases {
            guard let cmd = command(a, e) else { continue }
            let original = engineDefault(a, e)
            guard let k = chosen(a) ?? original else { continue }
            if let original, k != original { unbind.append("unbind \(original)") }
            bind.append("bind \(k) \"\(cmd)\"")
        }
        return (unbind + bind).joined(separator: "\n") + "\n"
    }

    // MARK: Préréglages

    static let presets: [(title: String, keys: [KeyAction: String])] = [
        ("W A S D", [:]),
        ("Z Q S D (AZERTY)", [.forward: "z", .left: "q", .back: "s", .right: "d"]),
        // Pas de tir sur Ctrl : Ctrl+flèche appartient à Mission Control.
        ("Flèches", [.forward: "uparrow", .back: "downarrow", .left: "leftarrow", .right: "rightarrow"]),
    ]

    /// Applique un préréglage aux déplacements ; les autres actions restent.
    static func apply(_ preset: [KeyAction: String]) {
        for a in [KeyAction.forward, .back, .left, .right] {
            if let k = preset[a] { UserDefaults.standard.set(k, forKey: a.prefKey) }
            else { UserDefaults.standard.removeObject(forKey: a.prefKey) }
        }
    }

    static func resetAll() {
        for a in KeyAction.allCases { UserDefaults.standard.removeObject(forKey: a.prefKey) }
    }

    // MARK: Noms

    /// Nom à l'écran d'une touche du moteur.
    static func label(_ key: String) -> String {
        switch key {
        case "space": "Espace"
        case "uparrow": "↑"
        case "downarrow": "↓"
        case "leftarrow": "←"
        case "rightarrow": "→"
        case "ctrl": "Ctrl"
        case "shift": "Maj"
        case "alt": "⌥"
        case "tab": "Tab"
        case "enter": "Entrée"
        case "backspace": "⌫"
        case "mouse1": "Clic"
        case "mouse2": "Clic droit"
        case "mouse3": "Clic milieu"
        case "mouse4": "Bouton 4"
        case "mouse5": "Bouton 5"
        case "mwheelup": "Molette ↑"
        case "mwheeldown": "Molette ↓"
        case "": "—"
        default: key.uppercased()
        }
    }

    /// Nom de moteur d'une touche pressée, ou nil si elle ne peut pas servir
    /// (Échap ouvre le menu, ⌘ appartient à macOS).
    static func engineName(_ event: NSEvent) -> String? {
        switch event.type {
        case .leftMouseDown: return "mouse1"
        case .rightMouseDown: return "mouse2"
        case .otherMouseDown: return "mouse\(min(event.buttonNumber + 1, 5))"
        case .scrollWheel: return event.scrollingDeltaY > 0 ? "mwheelup" : event.scrollingDeltaY < 0 ? "mwheeldown" : nil
        case .flagsChanged:
            switch event.keyCode {
            case 56, 60: return "shift"
            case 59, 62: return "ctrl"
            case 58, 61: return "alt"
            default: return nil
            }
        case .keyDown:
            let fkeys: [UInt16: Int] = [122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9, 109: 10, 103: 11, 111: 12]
            if let n = fkeys[event.keyCode] { return "f\(n)" }
            switch event.keyCode {
            case 49: return "space"
            case 48: return "tab"
            case 36, 76: return "enter"
            case 51: return "backspace"
            case 126: return "uparrow"
            case 125: return "downarrow"
            case 123: return "leftarrow"
            case 124: return "rightarrow"
            case 53: return nil
            default:
                // Le caractère de la disposition du clavier : c'est ce que voient les moteurs.
                guard let c = event.charactersIgnoringModifiers?.lowercased(), c.count == 1,
                      let ch = c.first, ch.isLetter || ch.isNumber || ",.;/-'[]<§".contains(ch) else { return nil }
                return c
            }
        default: return nil
        }
    }
}

// MARK: - Réglages → Touches

struct KeyBindingsSettings: View {
    @Environment(Catalog.self) private var catalog
    @State private var recording: String?
    @State private var monitor: Any?
    @State private var generation = 0

    var body: some View {
        let _ = generation
        Form {
            Section {
                HStack {
                    ForEach(KeyBindings.presets, id: \.title) { preset in
                        Button(preset.title) {
                            KeyBindings.apply(preset.keys)
                            generation += 1
                        }
                    }
                }
                ForEach(KeyAction.main) { a in
                    row(a.title, id: a.prefKey, label: pcLabel(a), clearable: false) { event in
                        KeyBindings.engineName(event).map { UserDefaults.standard.set($0, forKey: a.prefKey) } != nil
                    }
                }
            } header: {
                Text("Jeux PC")
            } footer: {
                Text("Doom, Quake I à 4, Doom 3, Return to Castle Wolfenstein et les jeux Build. La souris vise et le clic tire toujours. Le saut et l'accroupissement n'existent pas dans Doom d'origine ; « Utiliser » sert dans Doom, RTCW et les jeux Build.")
            }

            Section {
                ForEach(KeyAction.others) { a in
                    row(a.title, id: a.prefKey, label: KeyBindings.chosen(a).map(KeyBindings.label) ?? "Celle du jeu", clearable: KeyBindings.chosen(a) != nil) { event in
                        KeyBindings.engineName(event).map { UserDefaults.standard.set($0, forKey: a.prefKey) } != nil
                    }
                }
            } header: {
                Text("Jeux PC : autres actions")
            } footer: {
                Text("Pour les commandes dont la touche d'origine demande Maj sur votre clavier (« = », « + », « [ »…), ou que vous préférez ailleurs. Chaque jeu ignore celles qu'il n'a pas.")
            }

            mameSection("Arcade : joueur 1", MAMEKeys.player1)
            mameSection("Arcade : joueur 2", MAMEKeys.player2)
            Section {
                ForEach(MAMEKeys.system) { p in mameRow(p) }
            } header: {
                Text("Arcade : MAME")
            } footer: {
                Text("Les touches portent le nom écrit sur votre clavier. Une touche changée pour un seul jeu dans le menu de MAME (Tab) garde la priorité.")
            }

            Section {
                Text("Jeux DOS : sur la fiche du jeu, « Touches de ce jeu… » ouvre l'éditeur de DOSBox ; ce que vous y enregistrez ne vaut que pour ce jeu.")
                Text("Aventures : « Options de ScummVM… » sur la fiche d'un jeu ouvre ses options, onglet « Touches ».")
            } header: {
                Text("Jeux DOS et aventures")
            }
            .font(.callout)

            Section {
                Button("Revenir aux touches d'origine") {
                    KeyBindings.resetAll()
                    for p in MAMEKeys.all { UserDefaults.standard.removeObject(forKey: p.prefKey) }
                    generation += 1
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear(perform: stopRecording)
    }

    private func mameSection(_ title: String, _ ports: [MAMEKeys.Port]) -> some View {
        Section(title) {
            ForEach(ports) { p in mameRow(p) }
        }
    }

    private func mameRow(_ p: MAMEKeys.Port) -> some View {
        row(p.title, id: p.prefKey, label: MAMEKeys.label(p), clearable: UserDefaults.standard.object(forKey: p.prefKey) != nil) { event in
            MAMEKeys.code(event).map { UserDefaults.standard.set($0, forKey: p.prefKey) } != nil
        }
    }

    private func row(_ title: String, id: String, label: String, clearable: Bool,
                     store: @escaping (NSEvent) -> Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if clearable {
                Button {
                    UserDefaults.standard.removeObject(forKey: id)
                    generation += 1
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Revenir à la touche d'origine")
            }
            Button {
                startRecording(id, store)
            } label: {
                Text(recording == id ? "Appuyez sur une touche…" : label)
                    .frame(minWidth: 150)
            }
            .help("Cliquez, puis appuyez sur la touche ou le bouton de souris voulu. Échap annule.")
        }
    }

    /// Touche choisie, ou celle d'origine (qui varie selon le jeu pour certaines actions).
    private func pcLabel(_ a: KeyAction) -> String {
        if let k = KeyBindings.chosen(a) { return KeyBindings.label(k) }
        switch a {
        case .jump: return "Espace (E : Build)"
        case .use: return "E (Espace : Build, F : RTCW)"
        default: return KeyBindings.label(KeyBindings.engineDefault(a, .quake2) ?? "")
        }
    }

    private func startRecording(_ id: String, _ store: @escaping (NSEvent) -> Bool) {
        stopRecording()
        recording = id
        // Le clic qui lance l'enregistrement ne compte pas : seuls les suivants.
        DispatchQueue.main.async {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]) { event in
                if event.type == .keyDown && event.keyCode == 53 {
                    stopRecording()
                    return nil
                }
                // Clic gauche : on clique ailleurs, la saisie s'annule (le tir au clic existe déjà).
                if event.type == .leftMouseDown {
                    stopRecording()
                    return event
                }
                if event.type == .flagsChanged && event.modifierFlags.intersection([.shift, .control, .option]).isEmpty {
                    return nil   // relâchement d'une touche de modification
                }
                if event.type == .scrollWheel && abs(event.scrollingDeltaY) < 1 { return nil }
                guard store(event) else { return nil }
                stopRecording()
                generation += 1
                return nil
            }
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
    }
}
