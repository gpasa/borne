import Foundation

/// Une machine de `mame -listxml`, réduite à ce que l'interface affiche.
struct Machine: Codable, Identifiable, Hashable {
    var id: String { name }

    var name: String
    var description = ""
    var year = ""
    var manufacturer = ""
    var sourcefile = ""
    var cloneOf: String?
    var romOf: String?
    var isBIOS = false
    var isMechanical = false
    /// Au moins une ROM ou un disque à fournir (les « nodump » ne comptent pas).
    var needsFiles = false
    var status = ""        // good, imperfect, preliminary
    var emulation = ""
    var savestate = false
    var players = 0
    var buttons = 0
    var controls: [String] = []
    var screen = ""        // raster, vector, lcd, svg
    var rotate = 0
    var width = 0
    var height = 0
    var refresh = 0.0
    var cpus: [String] = []

    var isClone: Bool { cloneOf != nil }
    var isVertical: Bool { rotate == 90 || rotate == 270 }
    var parentName: String { cloneOf ?? "" }

    /// Pour trier : les pilotes qui marchent d'abord.
    var statusRank: Int {
        switch status {
        case "good": 0
        case "imperfect": 1
        case "preliminary": 2
        default: 3
        }
    }

    var statusLabel: String {
        switch status {
        case "good": "Bon"
        case "imperfect": "Imparfait"
        case "preliminary": "Préliminaire"
        default: "—"
        }
    }
}

enum AuditResult: String, Codable {
    case good, bestAvailable, bad

    var isPlayable: Bool { self != .bad }

    var label: String {
        switch self {
        case .good: "Complet"
        case .bestAvailable: "Meilleur disponible"
        case .bad: "Incorrect"
        }
    }
}
