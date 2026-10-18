import Foundation

/// Lit la sortie de `mame -listxml` en flux. Les périphériques et les
/// machines non lançables sont écartés dès la lecture.
final class ListXMLParser: NSObject, XMLParserDelegate {
    private var machines: [Machine] = []
    private var current: Machine?
    private var skip = false
    private var depth = 0
    private var text = ""
    private var capturing = false
    private let progress: (Int) -> Void

    init(progress: @escaping (Int) -> Void) {
        self.progress = progress
    }

    func parse(_ url: URL) throws -> [Machine] {
        guard let parser = XMLParser(contentsOf: url) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        if !parser.parse() {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return machines
    }

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes a: [String: String] = [:]) {
        if element == "machine" {
            depth = 0
            skip = a["isdevice"] == "yes" || a["runnable"] == "no"
            var m = Machine(name: a["name"] ?? "")
            m.sourcefile = a["sourcefile"] ?? ""
            m.cloneOf = a["cloneof"]
            m.romOf = a["romof"]
            m.isBIOS = a["isbios"] == "yes"
            m.isMechanical = a["ismechanical"] == "yes"
            current = m
            return
        }
        guard current != nil, !skip else { return }
        depth += 1
        if depth == 2 && element == "control", let t = a["type"] {
            if !current!.controls.contains(t) { current!.controls.append(t) }
            current!.buttons = max(current!.buttons, Int(a["buttons"] ?? "") ?? 0)
            return
        }
        guard depth == 1 else { return }

        switch element {
        case "description", "year", "manufacturer":
            text = ""
            capturing = true
        case "rom", "disk":
            if a["status"] != "nodump" { current!.needsFiles = true }
        case "chip":
            if a["type"] == "cpu", let n = a["name"], !current!.cpus.contains(n) {
                current!.cpus.append(n)
            }
        case "display":
            if current!.screen.isEmpty {
                current!.screen = a["type"] ?? ""
                current!.rotate = Int(a["rotate"] ?? "") ?? 0
                current!.width = Int(a["width"] ?? "") ?? 0
                current!.height = Int(a["height"] ?? "") ?? 0
                current!.refresh = Double(a["refresh"] ?? "") ?? 0
            }
        case "input":
            current!.players = Int(a["players"] ?? "") ?? 0
        case "driver":
            current!.status = a["status"] ?? ""
            current!.emulation = a["emulation"] ?? ""
            current!.savestate = a["savestate"] == "supported"
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?,
                qualifiedName: String?) {
        if element == "machine" {
            if let m = current, !skip {
                machines.append(m)
                if machines.count % 1000 == 0 { progress(machines.count) }
            }
            current = nil
            return
        }
        guard current != nil, !skip else { return }
        if depth == 1 && capturing {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch element {
            case "description": current!.description = value
            case "year": current!.year = value
            case "manufacturer": current!.manufacturer = value
            default: break
            }
            capturing = false
        }
        depth -= 1
    }
}
