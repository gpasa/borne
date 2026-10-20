import Foundation

/// Modules que Borne ne distribue pas lui-même et télécharge sur demande :
/// moteurs (licences incompatibles avec un paquet GPL), patchs officiels d'id
/// Software (à accepter par l'utilisateur), Freedoom. Liste pour le
/// téléchargement « une fois pour toutes » des réglages.
struct ExternalModule: Identifiable {
    let id: String
    let title: String
    let detail: String
    let size: String
    /// Patch d'id Software : sa licence doit être acceptée par l'utilisateur.
    let idLicense: URL?
    let isSupported: Bool
    let isInstalled: () -> Bool
    let install: (@escaping (Double) -> Void) async throws -> Void

    static var all: [ExternalModule] {
        [
            ExternalModule(id: "freedoom", title: "Freedoom \(Freedoom.version)", detail: "Doom entièrement libre",
                           size: Freedoom.size, idLicense: nil, isSupported: true,
                           isInstalled: { Freedoom.isInstalled }, install: Freedoom.install),
            ExternalModule(id: "raze", title: "Raze \(Raze.version)", detail: "Duke Nukem 3D, Blood, Shadow Warrior…",
                           size: Raze.size, idLicense: nil, isSupported: true,
                           isInstalled: { Raze.executable != nil }, install: Raze.install),
            ExternalModule(id: "scummvm", title: "ScummVM \(ScummVM.version)", detail: "Jeux d'aventure LucasArts, Revolution…",
                           size: ScummVM.size, idLicense: nil, isSupported: true,
                           isInstalled: { ScummVM.executable != nil }, install: ScummVM.install),
            ExternalModule(id: "openq4", title: "openQ4 \(OpenQ4.version)", detail: "Quake 4 (Apple silicon)",
                           size: OpenQ4.size, idLicense: nil, isSupported: OpenQ4.isSupported,
                           isInstalled: { OpenQ4.executable != nil }, install: OpenQ4.install),
            ExternalModule(id: "q3patch", title: "Quake III Arena 1.32", detail: "Mise à jour d'id Software",
                           size: Quake3Patch.size, idLicense: Quake3Patch.licenseURL, isSupported: true,
                           isInstalled: { Quake3Patch.isInstalled }, install: Quake3Patch.install),
            ExternalModule(id: "q4patch", title: "Quake 4 1.4.2", detail: "Mise à jour d'id Software (DVD d'origine)",
                           size: Quake4Patch.size, idLicense: Quake4Patch.pageURL, isSupported: true,
                           isInstalled: { Quake4Patch.isInstalled }, install: Quake4Patch.install),
            ExternalModule(id: "d3patch", title: "Doom 3 1.3.1", detail: "Mise à jour d'id Software (DVD d'origine)",
                           size: Doom3Patch.size, idLicense: Doom3Patch.pageURL, isSupported: true,
                           isInstalled: { Doom3Patch.isInstalled }, install: Doom3Patch.install),
        ]
    }
}
