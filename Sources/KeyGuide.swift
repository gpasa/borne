import AppKit
import SwiftUI

/// Touches utiles pour un jeu, d'après ses commandes et les touches choisies
/// dans Borne (MAMEKeys, KeyBindings).
enum KeyGuide {
    struct Entry: Hashable {
        let keys: String
        let action: String
    }


    static func game(_ m: Machine) -> [Entry] {
        if let engine = m.engineKind { return engineKeys(engine) }
        let k = { (id: String) in MAMEKeys.label(id: id) ?? "?" }
        var e = [Entry(keys: k("COIN1"), action: String(localized: "Insérer une pièce")),
                 Entry(keys: k("START1"), action: String(localized: "Start (1 joueur)"))]
        let c = Set(m.controls)
        if !c.isDisjoint(with: ["joy", "doublejoy", "stick", "triplejoy"]) {
            e.append(Entry(keys: ["LEFT", "UP", "RIGHT", "DOWN"].map { k("P1_JOYSTICK_\($0)") }.joined(separator: " "), action: String(localized: "Joystick")))
        }
        if !c.isDisjoint(with: ["dial", "paddle", "trackball", "mouse", "lightgun", "positional"]) {
            e.append(Entry(keys: String(localized: "Souris"), action: String(localized: "Volant, trackball ou pistolet")))
        }
        let n = min(m.buttons, 6)
        if n > 0 {
            e.append(Entry(keys: (1...n).map { k("P1_BUTTON\($0)") }.joined(separator: " "),
                           action: n == 1 ? String(localized: "Bouton") : String(localized: "Boutons 1 à \(n)")))
        }
        if m.players >= 2 {
            e.append(Entry(keys: String(localized: "\(k("COIN2")) puis \(k("START2"))"), action: String(localized: "Pièce et Start (joueur 2)")))
            e.append(Entry(keys: ["UP", "LEFT", "DOWN", "RIGHT"].map { k("P2_JOYSTICK_\($0)") }.joined(separator: " "), action: String(localized: "Joystick joueur 2")))
            let n2 = min(m.buttons, 4)
            if n2 > 0 {
                e.append(Entry(keys: (1...n2).map { k("P2_BUTTON\($0)") }.joined(separator: " "), action: String(localized: "Boutons joueur 2")))
            }
        }
        return e
    }

    /// Touches par défaut des moteurs, avec X en tir de secours (Ctrl+flèche
    /// déclenche Mission Control).
    /// Touche choisie dans Borne (Réglages → Touches) pour une action.
    private static func key(_ a: KeyAction, _ e: Engine) -> String {
        KeyBindings.label(KeyBindings.key(a, e))
    }

    private static func move(_ e: Engine) -> String {
        [KeyAction.forward, .left, .back, .right].map { key($0, e) }.joined(separator: " ")
    }

    static func engineKeys(_ e: Engine) -> [Entry] {
        switch e {
        case .doom: [
            Entry(keys: move(e), action: String(localized: "Se déplacer (ou flèches)")),
            Entry(keys: String(localized: "Souris"), action: String(localized: "Viser")),
            Entry(keys: String(localized: "Clic · \(key(.fire, e))"), action: String(localized: "Tirer")),
            Entry(keys: String(localized: "Espace · \(key(.use, e))"), action: String(localized: "Ouvrir, utiliser")),
            Entry(keys: String(localized: "1 à 7"), action: String(localized: "Armes")),
            Entry(keys: "Tab", action: String(localized: "Carte")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, sauvegarde, quitter")),
        ]
        case .quake: [
            Entry(keys: move(e), action: String(localized: "Se déplacer")),
            Entry(keys: String(localized: "Souris"), action: String(localized: "Viser")),
            Entry(keys: String(localized: "Clic · \(key(.fire, e))"), action: String(localized: "Tirer")),
            Entry(keys: key(.jump, e), action: String(localized: "Sauter")),
            Entry(keys: String(localized: "1 à 8"), action: String(localized: "Armes")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, sauvegarde, quitter")),
        ]
        case .build: [
            Entry(keys: String(localized: "Flèches · \(move(e))"), action: String(localized: "Se déplacer")),
            Entry(keys: String(localized: "Souris"), action: String(localized: "Viser")),
            Entry(keys: String(localized: "Clic · \(key(.fire, e))"), action: String(localized: "Tirer")),
            Entry(keys: key(.use, e), action: String(localized: "Ouvrir, utiliser")),
            Entry(keys: key(.jump, e), action: String(localized: "Sauter")),
            Entry(keys: key(.crouch, e), action: String(localized: "S'accroupir")),
            Entry(keys: String(localized: "1 à 0"), action: String(localized: "Armes")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, sauvegarde, quitter")),
        ]
        case .quake2: [
            Entry(keys: String(localized: "\(move(e)) · flèches"), action: String(localized: "Se déplacer")),
            Entry(keys: String(localized: "Souris"), action: String(localized: "Viser")),
            Entry(keys: String(localized: "Clic · \(key(.fire, e))"), action: String(localized: "Tirer")),
            Entry(keys: key(.jump, e), action: String(localized: "Sauter")),
            Entry(keys: key(.crouch, e), action: String(localized: "S'accroupir")),
            Entry(keys: "F1", action: String(localized: "Ordinateur de mission")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, sauvegarde, quitter")),
        ]
        case .doom3: [
            Entry(keys: move(e), action: String(localized: "Se déplacer")),
            Entry(keys: String(localized: "Souris"), action: String(localized: "Viser")),
            Entry(keys: String(localized: "Clic · \(key(.fire, e))"), action: String(localized: "Tirer")),
            Entry(keys: "F", action: String(localized: "Lampe torche")),
            Entry(keys: key(.jump, e), action: String(localized: "Sauter")),
            Entry(keys: key(.crouch, e), action: String(localized: "S'accroupir")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, sauvegarde, quitter")),
        ]
        case .quake4: [
            Entry(keys: move(e), action: String(localized: "Se déplacer")),
            Entry(keys: String(localized: "Souris"), action: String(localized: "Viser")),
            Entry(keys: String(localized: "Clic · \(key(.fire, e))"), action: String(localized: "Tirer")),
            Entry(keys: key(.jump, e), action: String(localized: "Sauter")),
            Entry(keys: key(.crouch, e), action: String(localized: "S'accroupir")),
            Entry(keys: String(localized: "Molette · 1 à 9"), action: String(localized: "Armes")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, sauvegarde, quitter")),
        ]
        case .scummvm: [
            Entry(keys: String(localized: "Clic"), action: String(localized: "Agir, marcher, choisir un verbe")),
            Entry(keys: "Ctrl F5", action: String(localized: "Menu : sauvegarder, charger, quitter")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Passer une scène")),
            Entry(keys: String(localized: "Point"), action: String(localized: "Passer une réplique")),
            Entry(keys: "⌘ Q", action: String(localized: "Quitter ScummVM")),
        ]
        case .dos: [
            Entry(keys: String(localized: "Selon le jeu"), action: String(localized: "Flèches, Ctrl, Alt, Espace le plus souvent")),
            Entry(keys: "⌘ F10", action: String(localized: "Capturer ou libérer la souris")),
            Entry(keys: String(localized: "⌥ Entrée"), action: String(localized: "Plein écran ou fenêtre")),
            Entry(keys: "⌘ Q", action: String(localized: "Quitter DOSBox")),
        ]
        case .rtcw: [
            Entry(keys: move(e), action: String(localized: "Se déplacer")),
            Entry(keys: String(localized: "Souris"), action: String(localized: "Viser")),
            Entry(keys: String(localized: "Clic · \(key(.fire, e))"), action: String(localized: "Tirer")),
            Entry(keys: key(.jump, e), action: String(localized: "Sauter")),
            Entry(keys: key(.use, e), action: String(localized: "Utiliser, ouvrir")),
            Entry(keys: String(localized: "1 à 7"), action: String(localized: "Armes")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, sauvegarde, quitter")),
        ]
        case .quake3: [
            Entry(keys: move(e), action: String(localized: "Se déplacer")),
            Entry(keys: String(localized: "Souris"), action: String(localized: "Viser")),
            Entry(keys: String(localized: "Clic · \(key(.fire, e))"), action: String(localized: "Tirer")),
            Entry(keys: key(.jump, e), action: String(localized: "Sauter")),
            Entry(keys: key(.crouch, e), action: String(localized: "S'accroupir")),
            Entry(keys: String(localized: "Molette · 1 à 9"), action: String(localized: "Armes")),
            Entry(keys: "Tab", action: String(localized: "Scores")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, quitter")),
        ]
        case .wolf3d: [
            Entry(keys: "← ↑ → ↓", action: String(localized: "Se déplacer")),
            Entry(keys: "X", action: String(localized: "Tirer")),
            Entry(keys: String(localized: "Espace"), action: String(localized: "Ouvrir les portes")),
            Entry(keys: "⌥ + ← →", action: String(localized: "Pas de côté")),
            Entry(keys: String(localized: "Maj"), action: String(localized: "Courir")),
            Entry(keys: String(localized: "1 à 4"), action: String(localized: "Armes")),
            Entry(keys: String(localized: "Échap"), action: String(localized: "Menu, sauvegarde, quitter")),
        ]
        }
    }

    /// Sur un clavier Mac, les touches F demandent fn.
    static var system: [Entry] { [
        Entry(keys: String(localized: "Échap"), action: String(localized: "Quitter et revenir à Borne")),
        Entry(keys: MAMEKeys.label(id: "UI_PAUSE") ?? "P", action: String(localized: "Pause")),
        Entry(keys: "fn F3", action: String(localized: "Remise à zéro")),
        Entry(keys: String(localized: "Maj fn F7"), action: String(localized: "Sauver l'état")),
        Entry(keys: "fn F7", action: String(localized: "Recharger l'état")),
        Entry(keys: "fn F12", action: String(localized: "Capture d'écran")),
        Entry(keys: MAMEKeys.label(id: "UI_CONFIGURE") ?? "Tab", action: String(localized: "Menu de MAME (touches, réglages)")),
    ] }
}

struct KeyGuideView: View {
    let machine: Machine

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 4) {
            ForEach(KeyGuide.game(machine), id: \.self) { row($0) }
            if machine.engine == nil {
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(KeyGuide.system, id: \.self) { row($0) }
            }
        }
    }

    private func row(_ e: KeyGuide.Entry) -> some View {
        GridRow {
            Text(e.keys)
                .font(.callout.monospaced().weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
                .gridColumnAlignment(.trailing)
            Text(e.action).font(.callout)
        }
    }
}

/// Panneau flottant montré au lancement d'un jeu. Il ne prend pas le focus :
/// le clavier reste à MAME.
@MainActor
final class KeyHUD {
    static let shared = KeyHUD()
    private var panel: NSPanel?
    private var closeTask: Task<Void, Never>?

    func show(for m: Machine) {
        hide()
        let content = VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(m.description).font(.headline).lineLimit(1)
                Spacer()
                Button {
                    KeyHUD.shared.hide()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            KeyGuideView(machine: m)
        }
        .padding(14)
        .frame(width: 330)

        let host = NSHostingView(rootView: content)
        host.frame.size = host.fittingSize
        let p = NSPanel(contentRect: host.frame,
                        styleMask: [.nonactivatingPanel, .borderless, .hudWindow, .utilityWindow],
                        backing: .buffered, defer: false)
        p.contentView = NSVisualEffectView()
        if let fx = p.contentView as? NSVisualEffectView {
            fx.material = .hudWindow
            fx.state = .active
            fx.wantsLayer = true
            fx.layer?.cornerRadius = 12
            fx.addSubview(host)
        }
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if let screen = NSScreen.main?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: screen.maxX - host.frame.width - 20,
                                     y: screen.maxY - host.frame.height - 20))
        }
        p.orderFrontRegardless()
        panel = p
        closeTask = Task {
            try? await Task.sleep(for: .seconds(20))
            if !Task.isCancelled { hide() }
        }
    }

    func hide() {
        closeTask?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }
}
