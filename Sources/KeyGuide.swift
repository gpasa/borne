import AppKit
import SwiftUI

/// Touches utiles pour un jeu, d'après ses commandes et le fichier
/// ctrlr/borne_mac.cfg (boutons du joueur 1 sur Z X C V B N, pas sur Ctrl).
enum KeyGuide {
    struct Entry: Hashable {
        let keys: String
        let action: String
    }

    static let player1Buttons = ["Z", "X", "C", "V", "B", "N"]
    static let player2Buttons = ["A", "S", "Q", "W"]

    static func game(_ m: Machine) -> [Entry] {
        if let engine = m.engineKind { return engineKeys(engine) }
        var e = [Entry(keys: "5", action: "Insérer une pièce"),
                 Entry(keys: "1", action: "Start (1 joueur)")]
        let c = Set(m.controls)
        if !c.isDisjoint(with: ["joy", "doublejoy", "stick", "triplejoy"]) {
            e.append(Entry(keys: "← ↑ → ↓", action: "Joystick"))
        }
        if !c.isDisjoint(with: ["dial", "paddle", "trackball", "mouse", "lightgun", "positional"]) {
            e.append(Entry(keys: "Souris", action: "Volant, trackball ou pistolet"))
        }
        let n = min(m.buttons, player1Buttons.count)
        if n > 0 {
            e.append(Entry(keys: player1Buttons.prefix(n).joined(separator: " "),
                           action: n == 1 ? "Bouton" : "Boutons 1 à \(n)"))
        }
        if m.players >= 2 {
            e.append(Entry(keys: "6 puis 2", action: "Pièce et Start (joueur 2)"))
            e.append(Entry(keys: "R D F G", action: "Joystick joueur 2"))
            let n2 = min(m.buttons, player2Buttons.count)
            if n2 > 0 {
                e.append(Entry(keys: player2Buttons.prefix(n2).joined(separator: " "), action: "Boutons joueur 2"))
            }
        }
        return e
    }

    /// Touches par défaut des moteurs, avec X en tir de secours (Ctrl+flèche
    /// déclenche Mission Control).
    static func engineKeys(_ e: Engine) -> [Entry] {
        switch e {
        case .doom: [
            Entry(keys: "W A S D", action: "Se déplacer (ou flèches)"),
            Entry(keys: "Souris", action: "Viser"),
            Entry(keys: "Clic · X", action: "Tirer"),
            Entry(keys: "Espace · E", action: "Ouvrir, utiliser"),
            Entry(keys: "1 à 7", action: "Armes"),
            Entry(keys: "Tab", action: "Carte"),
            Entry(keys: "Échap", action: "Menu, sauvegarde, quitter"),
        ]
        case .quake: [
            Entry(keys: "W A S D", action: "Se déplacer"),
            Entry(keys: "Souris", action: "Viser"),
            Entry(keys: "Clic · X", action: "Tirer"),
            Entry(keys: "Espace", action: "Sauter"),
            Entry(keys: "1 à 8", action: "Armes"),
            Entry(keys: "Échap", action: "Menu, sauvegarde, quitter"),
        ]
        case .wolf3d: [
            Entry(keys: "← ↑ → ↓", action: "Se déplacer"),
            Entry(keys: "X", action: "Tirer"),
            Entry(keys: "Espace", action: "Ouvrir les portes"),
            Entry(keys: "⌥ + ← →", action: "Pas de côté"),
            Entry(keys: "Maj", action: "Courir"),
            Entry(keys: "1 à 4", action: "Armes"),
            Entry(keys: "Échap", action: "Menu, sauvegarde, quitter"),
        ]
        }
    }

    /// Sur un clavier Mac, les touches F demandent fn.
    static let system: [Entry] = [
        Entry(keys: "Échap", action: "Quitter et revenir à Borne"),
        Entry(keys: "P", action: "Pause"),
        Entry(keys: "fn F3", action: "Remise à zéro"),
        Entry(keys: "Maj fn F7", action: "Sauver l'état"),
        Entry(keys: "fn F7", action: "Recharger l'état"),
        Entry(keys: "fn F12", action: "Capture d'écran"),
        Entry(keys: "Tab", action: "Menu de MAME (touches, réglages)"),
    ]
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
