import AppKit
import Carbon.HIToolbox

/// Touches de l'arcade, choisies dans Borne. MAME désigne les touches par leur
/// place sur un clavier américain (KEYCODE_Z est la touche marquée Y sur un
/// clavier suisse) : Borne garde le code physique de la touche pressée et
/// affiche ce qui est écrit dessus avec la disposition du Mac.
/// Le fichier ctrlr/borne_mac.cfg est réécrit à chaque lancement ; ce qui est
/// changé dans le menu de MAME (Tab) l'emporte toujours.
enum MAMEKeys {
    struct Port: Identifiable {
        let id: String            // type de port MAME
        let title: String
        let key: Int              // code de touche du Mac, ou -1, -2, -3 pour les clics
        var prefKey: String { "mame.\(id)" }
    }

    static let player1: [Port] = [
        .init(id: "P1_JOYSTICK_UP", title: "Haut", key: kVK_UpArrow),
        .init(id: "P1_JOYSTICK_DOWN", title: "Bas", key: kVK_DownArrow),
        .init(id: "P1_JOYSTICK_LEFT", title: "Gauche", key: kVK_LeftArrow),
        .init(id: "P1_JOYSTICK_RIGHT", title: "Droite", key: kVK_RightArrow),
        .init(id: "P1_BUTTON1", title: "Bouton 1", key: kVK_ANSI_Z),
        .init(id: "P1_BUTTON2", title: "Bouton 2", key: kVK_ANSI_X),
        .init(id: "P1_BUTTON3", title: "Bouton 3", key: kVK_ANSI_C),
        .init(id: "P1_BUTTON4", title: "Bouton 4", key: kVK_ANSI_V),
        .init(id: "P1_BUTTON5", title: "Bouton 5", key: kVK_ANSI_B),
        .init(id: "P1_BUTTON6", title: "Bouton 6", key: kVK_ANSI_N),
        .init(id: "COIN1", title: "Pièce", key: kVK_ANSI_5),
        .init(id: "START1", title: "Start", key: kVK_ANSI_1),
    ]

    static let player2: [Port] = [
        .init(id: "P2_JOYSTICK_UP", title: "Haut", key: kVK_ANSI_R),
        .init(id: "P2_JOYSTICK_DOWN", title: "Bas", key: kVK_ANSI_F),
        .init(id: "P2_JOYSTICK_LEFT", title: "Gauche", key: kVK_ANSI_D),
        .init(id: "P2_JOYSTICK_RIGHT", title: "Droite", key: kVK_ANSI_G),
        .init(id: "P2_BUTTON1", title: "Bouton 1", key: kVK_ANSI_A),
        .init(id: "P2_BUTTON2", title: "Bouton 2", key: kVK_ANSI_S),
        .init(id: "P2_BUTTON3", title: "Bouton 3", key: kVK_ANSI_Q),
        .init(id: "P2_BUTTON4", title: "Bouton 4", key: kVK_ANSI_W),
        .init(id: "COIN2", title: "Pièce", key: kVK_ANSI_6),
        .init(id: "START2", title: "Start", key: kVK_ANSI_2),
    ]

    static let system: [Port] = [
        .init(id: "UI_PAUSE", title: "Pause", key: kVK_ANSI_P),
        .init(id: "UI_CONFIGURE", title: "Menu de MAME", key: kVK_Tab),
    ]

    static var all: [Port] { player1 + player2 + system }

    static func key(_ p: Port) -> Int {
        UserDefaults.standard.object(forKey: p.prefKey) as? Int ?? p.key
    }

    static func label(_ p: Port) -> String { label(key(p)) }

    static func label(id: String) -> String? { all.first { $0.id == id }.map(label) }

    // MARK: Fichier pour MAME

    static var ctrlrDirectory: URL { Prefs.userDataRoot.appendingPathComponent("ctrlr") }

    /// Réécrit ctrlr/borne_mac.cfg d'après les touches choisies.
    static func write() throws {
        var lines = ""
        for p in all {
            guard let code = mameCode(key(p)) else { continue }
            lines += "            <port type=\"\(p.id)\"><newseq type=\"standard\">\(code)</newseq></port>\n"
        }
        let xml = """
        <?xml version="1.0"?>
        <!-- Écrit par Borne (Réglages → Touches) à chaque lancement : modifier les touches là-bas. -->
        <mameconfig version="10">
            <system name="default">
                <input>
        \(lines)        </input>
            </system>
        </mameconfig>

        """
        try FileManager.default.createDirectory(at: ctrlrDirectory, withIntermediateDirectories: true)
        try xml.write(to: ctrlrDirectory.appendingPathComponent("borne_mac.cfg"), atomically: true, encoding: .utf8)
    }

    // MARK: Codes

    /// Code d'une touche ou d'un clic pressé, ou nil (Échap, ⌘).
    static func code(_ event: NSEvent) -> Int? {
        switch event.type {
        case .leftMouseDown: return -1
        case .rightMouseDown: return -2
        case .otherMouseDown: return -3
        case .keyDown, .flagsChanged:
            let k = Int(event.keyCode)
            return k == kVK_Escape || k == kVK_Command || k == kVK_RightCommand || mameCode(k) == nil ? nil : k
        default: return nil
        }
    }

    private static let names: [Int: String] = {
        var n: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
            kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
            kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
            kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_ANSI_Minus: "MINUS", kVK_ANSI_Equal: "EQUALS", kVK_ANSI_LeftBracket: "OPENBRACE",
            kVK_ANSI_RightBracket: "CLOSEBRACE", kVK_ANSI_Semicolon: "COLON", kVK_ANSI_Quote: "QUOTE",
            kVK_ANSI_Backslash: "BACKSLASH", kVK_ANSI_Comma: "COMMA", kVK_ANSI_Period: "STOP",
            kVK_ANSI_Slash: "SLASH", kVK_ANSI_Grave: "BACKSLASH2", kVK_ISO_Section: "TILDE",
            kVK_Return: "ENTER", kVK_Tab: "TAB", kVK_Space: "SPACE", kVK_Delete: "BACKSPACE",
            kVK_ForwardDelete: "DEL", kVK_Home: "HOME", kVK_End: "END", kVK_PageUp: "PGUP", kVK_PageDown: "PGDN",
            kVK_UpArrow: "UP", kVK_DownArrow: "DOWN", kVK_LeftArrow: "LEFT", kVK_RightArrow: "RIGHT",
            kVK_Shift: "LSHIFT", kVK_RightShift: "RSHIFT", kVK_Control: "LCONTROL", kVK_RightControl: "RCONTROL",
            kVK_Option: "LALT", kVK_RightOption: "RALT", kVK_CapsLock: "CAPSLOCK",
            kVK_ANSI_Keypad0: "0_PAD", kVK_ANSI_Keypad1: "1_PAD", kVK_ANSI_Keypad2: "2_PAD", kVK_ANSI_Keypad3: "3_PAD",
            kVK_ANSI_Keypad4: "4_PAD", kVK_ANSI_Keypad5: "5_PAD", kVK_ANSI_Keypad6: "6_PAD", kVK_ANSI_Keypad7: "7_PAD",
            kVK_ANSI_Keypad8: "8_PAD", kVK_ANSI_Keypad9: "9_PAD", kVK_ANSI_KeypadEnter: "ENTER_PAD",
            kVK_ANSI_KeypadPlus: "PLUS_PAD", kVK_ANSI_KeypadMinus: "MINUS_PAD", kVK_ANSI_KeypadMultiply: "ASTERISK",
            kVK_ANSI_KeypadDivide: "SLASH_PAD", kVK_ANSI_KeypadDecimal: "DEL_PAD",
        ]
        let f = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12]
        for (i, k) in f.enumerated() { n[k] = "F\(i + 1)" }
        return n
    }()

    static func mameCode(_ key: Int) -> String? {
        if key < 0 { return "MOUSECODE_1_BUTTON\(-key)" }
        return names[key].map { "KEYCODE_\($0)" }
    }

    /// Ce qui est écrit sur la touche, avec la disposition du clavier du Mac.
    static func label(_ key: Int) -> String {
        switch key {
        case -1: return "Clic"
        case -2: return "Clic droit"
        case -3: return "Clic milieu"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_Space: return "Espace"
        case kVK_Tab: return "Tab"
        case kVK_Return: return "Entrée"
        case kVK_Delete: return "⌫"
        case kVK_Shift, kVK_RightShift: return "Maj"
        case kVK_Control, kVK_RightControl: return "Ctrl"
        case kVK_Option, kVK_RightOption: return "⌥"
        case kVK_CapsLock: return "Verr. maj"
        case kVK_ANSI_KeypadEnter: return "Entrée (pavé)"
        default:
            if let n = names[key], n.hasPrefix("F"), Int(n.dropFirst()) != nil { return n }
            if let c = layoutCharacter(key) {
                return names[key]?.hasSuffix("_PAD") == true ? "\(c) (pavé)" : c
            }
            return names[key] ?? "?"
        }
    }

    private static func layoutCharacter(_ key: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, UInt16(key), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        let s = String(utf16CodeUnits: chars, count: length).uppercased()
        return s.trimmingCharacters(in: .whitespaces).isEmpty ? nil : s
    }
}
