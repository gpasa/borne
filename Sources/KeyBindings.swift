import AppKit
import SwiftUI

/// Touches des jeux PC, choisies une fois dans Borne pour tous les moteurs
/// de la famille id/ZDoom (Doom, Quake I à 4, Doom 3, RTCW, jeux Build).
/// Borne les écrit dans le fichier qu'il fait exécuter au moteur à chaque
/// lancement ; les choix faits dans le menu du jeu valent pour les autres touches.
enum KeyAction: String, CaseIterable, Identifiable {
    case forward, back, left, right, fire, jump, crouch, use

    var id: String { rawValue }

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
        }
    }

    var prefKey: String { "key.\(rawValue)" }
}

enum KeyBindings {
    /// Commande du moteur pour chaque action ; absente si le jeu ne l'a pas.
    static func command(_ a: KeyAction, _ e: Engine) -> String? {
        let idTech4 = e == .doom3 || e == .quake4
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
        }
    }

    static let supported: Set<Engine> = [.doom, .quake, .quake2, .quake3, .rtcw, .doom3, .quake4, .build]

    /// Touche d'origine du moteur, que Borne libère quand l'action change de touche.
    static func engineDefault(_ a: KeyAction, _ e: Engine) -> String {
        switch a {
        case .forward: "w"
        case .back: "s"
        case .left: "a"
        case .right: "d"
        case .fire: "x"
        case .jump: e == .build ? "e" : "space"
        case .crouch: "c"
        case .use: e == .build ? "space" : e == .rtcw ? "f" : "e"
        }
    }

    /// Touche choisie, ou celle d'origine.
    static func key(_ a: KeyAction, _ e: Engine) -> String {
        UserDefaults.standard.string(forKey: a.prefKey) ?? engineDefault(a, e)
    }

    /// Lignes à exécuter par le moteur.
    static func script(for e: Engine) -> String {
        var unbind: [String] = []
        var bind: [String] = []
        for a in KeyAction.allCases {
            guard let cmd = command(a, e) else { continue }
            let k = key(a, e)
            let original = engineDefault(a, e)
            if k != original { unbind.append("unbind \(original)") }
            bind.append("bind \(k) \(cmd)")
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

    static func apply(_ preset: [KeyAction: String]) {
        for a in KeyAction.allCases {
            if let k = preset[a] { UserDefaults.standard.set(k, forKey: a.prefKey) }
            else { UserDefaults.standard.removeObject(forKey: a.prefKey) }
        }
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
        case .flagsChanged:
            switch event.keyCode {
            case 56, 60: return "shift"
            case 59, 62: return "ctrl"
            case 58, 61: return "alt"
            default: return nil
            }
        case .keyDown:
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
                      let ch = c.first, ch.isLetter || ch.isNumber || ",.;/-'[]".contains(ch) else { return nil }
                return c
            }
        default: return nil
        }
    }
}

// MARK: - Réglages

struct KeyBindingsSettings: View {
    @State private var recording: KeyAction?
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
            } header: {
                Text("Préréglages")
            } footer: {
                Text("Pour Doom, Quake I à 4, Doom 3, Return to Castle Wolfenstein et les jeux Build. La souris vise et le clic tire toujours.")
            }

            Section {
                ForEach(KeyAction.allCases) { a in
                    HStack {
                        Text(a.title)
                        Spacer()
                        Button {
                            startRecording(a)
                        } label: {
                            Text(recording == a ? "Appuyez sur une touche…" : label(a))
                                .frame(minWidth: 140)
                        }
                        .help("Cliquez, puis appuyez sur la touche ou le bouton de souris voulu. Échap annule.")
                    }
                }
            } header: {
                Text("Touches")
            } footer: {
                Text("Valables à partir du prochain lancement. Le saut et l'accroupissement n'existent pas dans Doom d'origine ; « Utiliser » sert dans Doom, RTCW et les jeux Build. Les autres touches se changent dans le menu de chaque jeu.")
            }

            Section {
                Button("Revenir aux touches d'origine") {
                    KeyBindings.apply([:])
                    generation += 1
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear(perform: stopRecording)
    }

    /// Touche choisie, ou celle d'origine (qui varie selon le jeu pour certaines actions).
    private func label(_ a: KeyAction) -> String {
        if let k = UserDefaults.standard.string(forKey: a.prefKey) { return KeyBindings.label(k) }
        switch a {
        case .jump: return "Espace (E : Build)"
        case .use: return "E (Espace : Build, F : RTCW)"
        default: return KeyBindings.label(KeyBindings.engineDefault(a, .quake2))
        }
    }

    private func startRecording(_ a: KeyAction) {
        stopRecording()
        recording = a
        // Le clic qui lance l'enregistrement ne compte pas : seuls les suivants.
        DispatchQueue.main.async {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in
                if event.type == .keyDown && event.keyCode == 53 {
                    stopRecording()
                    return nil
                }
                if event.type == .flagsChanged && event.modifierFlags.intersection([.shift, .control, .option]).isEmpty {
                    return nil   // relâchement d'une touche de modification
                }
                guard let name = KeyBindings.engineName(event) else { return nil }
                UserDefaults.standard.set(name, forKey: a.prefKey)
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
