import AppKit
import SwiftUI

/// Liste des jeux en NSTableView natif. Le Table de SwiftUI mesure la hauteur
/// de chaque ligne insérée : passer de 200 à 43 000 jeux figeait l'app.
/// Ici, hauteur fixe et reloadData : seules les lignes visibles sont dessinées.
struct GameTableView: NSViewRepresentable {
    let catalog: Catalog
    let rows: [Machine]
    let generation: Int
    let selection: String?

    func makeCoordinator() -> Coordinator { Coordinator(catalog: catalog) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = GameNSTableView()
        table.rowHeight = 22
        table.usesAutomaticRowHeights = false
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.allowsColumnReordering = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.style = .inset
        table.autosaveName = "BorneGames"
        table.autosaveTableColumns = true

        for spec in Column.all {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(spec.id))
            col.title = spec.title
            col.width = spec.width
            col.minWidth = spec.minWidth
            if let key = spec.sortKey {
                col.sortDescriptorPrototype = NSSortDescriptor(key: key, ascending: true)
            }
            table.addTableColumn(col)
        }

        let c = context.coordinator
        c.table = table
        table.dataSource = c
        table.delegate = c
        table.target = c
        table.doubleAction = #selector(Coordinator.doubleClicked)
        table.onReturn = { [weak c] in c?.launchSelected() }
        let menu = NSMenu()
        menu.delegate = c
        table.menu = menu
        table.sortDescriptors = [NSSortDescriptor(key: "description", ascending: true)]

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let c = context.coordinator
        guard let table = c.table else { return }
        if c.generation != generation {
            c.generation = generation
            c.rows = rows
            c.index = Dictionary(rows.enumerated().map { ($1.name, $0) }, uniquingKeysWith: { a, _ in a })
            c.programmatic = true
            table.reloadData()
            c.programmatic = false
        }
        // Remettre la sélection sans renvoyer d'événement au catalogue.
        let current = table.selectedRow >= 0 && table.selectedRow < c.rows.count ? c.rows[table.selectedRow].name : nil
        if current != selection {
            c.programmatic = true
            if let s = selection, let i = c.index[s] {
                table.selectRowIndexes([i], byExtendingSelection: false)
                table.scrollRowToVisible(i)
            } else {
                table.deselectAll(nil)
            }
            c.programmatic = false
        }
    }

    struct Column {
        let id: String
        let title: String
        let width: CGFloat
        let minWidth: CGFloat
        let sortKey: String?

        static let all: [Column] = [
            .init(id: "flags", title: "", width: 34, minWidth: 30, sortKey: nil),
            .init(id: "description", title: String(localized: "Jeu"), width: 320, minWidth: 150, sortKey: "description"),
            .init(id: "name", title: String(localized: "Nom"), width: 90, minWidth: 50, sortKey: "name"),
            .init(id: "manufacturer", title: String(localized: "Fabricant"), width: 160, minWidth: 70, sortKey: "manufacturer"),
            .init(id: "year", title: String(localized: "Année"), width: 50, minWidth: 40, sortKey: "year"),
            .init(id: "status", title: String(localized: "État"), width: 100, minWidth: 60, sortKey: "status"),
            .init(id: "parent", title: String(localized: "Original"), width: 80, minWidth: 50, sortKey: "parent"),
            .init(id: "source", title: String(localized: "Pilote"), width: 140, minWidth: 70, sortKey: "source"),
        ]
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        let catalog: Catalog
        weak var table: NSTableView?
        var rows: [Machine] = []
        var index: [String: Int] = [:]
        var generation = -1
        var programmatic = false

        init(catalog: Catalog) { self.catalog = catalog }

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
            guard let column, row < rows.count else { return nil }
            let id = column.identifier
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView) ?? makeCell(id)
            let m = rows[row]
            let dim = !catalog.available.contains(m.name)
            let field = cell.textField!
            field.textColor = dim ? .secondaryLabelColor : .labelColor
            switch id.rawValue {
            case "flags":
                var s = ""
                if catalog.favorites.contains(m.name) { s += "★" }
                if catalog.isLocal(m.name) { s += "⌂" }
                field.stringValue = s
                field.textColor = .systemYellow
                field.toolTip = catalog.isLocal(m.name) ? String(localized: "Installé sur ce Mac") : nil
            case "description":
                field.stringValue = m.isClone ? "    " + m.description : m.description
            case "name": field.stringValue = m.name
            case "manufacturer": field.stringValue = m.manufacturer
            case "year": field.stringValue = m.year
            case "status":
                let dot = NSAttributedString(string: "● ", attributes: [.foregroundColor: statusColor(m)])
                let text = NSMutableAttributedString(attributedString: dot)
                text.append(NSAttributedString(string: m.statusLabel, attributes: [.foregroundColor: field.textColor!]))
                field.attributedStringValue = text
            case "parent": field.stringValue = m.parentName
            case "source": field.stringValue = m.sourcefile
            default: field.stringValue = ""
            }
            return cell
        }

        private func makeCell(_ id: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = id
            let field = NSTextField(labelWithString: "")
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
            if id.rawValue == "name" || id.rawValue == "parent" {
                field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            }
            cell.addSubview(field)
            cell.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }

        private func statusColor(_ m: Machine) -> NSColor {
            switch m.status {
            case "good": .systemGreen
            case "imperfect": .systemOrange
            case "preliminary": .systemRed
            default: .systemGray
            }
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !programmatic, let table else { return }
            // Seul un clic ou une touche change le jeu choisi. Un rafraîchissement de la
            // liste (dossiers relus pendant que le jeu est sélectionné) peut décaler la
            // ligne choisie : on remet alors celle du catalogue, sans quoi « Lancer »
            // partirait sur un autre jeu.
            let input: Set<NSEvent.EventType> = [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .keyDown, .otherMouseDown]
            guard let type = NSApp.currentEvent?.type, input.contains(type) else {
                programmatic = true
                if let s = catalog.selection, let i = index[s] {
                    table.selectRowIndexes([i], byExtendingSelection: false)
                } else {
                    table.deselectAll(nil)
                }
                programmatic = false
                return
            }
            let r = table.selectedRow
            let name = r >= 0 && r < rows.count ? rows[r].name : nil
            if catalog.selection != name { catalog.selection = name }
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange old: [NSSortDescriptor]) {
            guard let d = tableView.sortDescriptors.first, let key = d.key else { return }
            let order: SortOrder = d.ascending ? .forward : .reverse
            let comparator: KeyPathComparator<Machine> = switch key {
            case "name": KeyPathComparator(\.name, order: order)
            case "manufacturer": KeyPathComparator(\.manufacturer, comparator: .localizedStandard, order: order)
            case "year": KeyPathComparator(\.year, order: order)
            case "status": KeyPathComparator(\.statusRank, order: order)
            case "parent": KeyPathComparator(\.parentName, order: order)
            case "source": KeyPathComparator(\.sourcefile, order: order)
            default: KeyPathComparator(\.description, comparator: .localizedStandard, order: order)
            }
            catalog.sortOrder = [comparator]
        }

        @objc func doubleClicked() {
            guard let table, table.clickedRow >= 0, table.clickedRow < rows.count else { return }
            catalog.launch(rows[table.clickedRow].name)
        }

        func launchSelected() {
            if let s = catalog.selection { catalog.launch(s) }
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let table, table.clickedRow >= 0, table.clickedRow < rows.count else { return }
            let name = rows[table.clickedRow].name
            func item(_ title: String, enabled: Bool = true, _ action: @escaping () -> Void) {
                let i = ClosureMenuItem(title: title, action: action)
                i.isEnabled = enabled
                menu.addItem(i)
            }
            menu.autoenablesItems = false
            item(String(localized: "Lancer"), enabled: catalog.running == nil) { [catalog] in catalog.launch(name) }
            item(catalog.favorites.contains(name) ? String(localized: "Retirer des favoris") : String(localized: "Ajouter aux favoris")) { [catalog] in
                catalog.toggleFavorite(name)
            }
            if catalog.hasDisplaySettings(name) {
                item(String(localized: "Réinitialiser l'affichage")) { [catalog] in catalog.resetDisplay(name) }
            }
            if catalog.hasSettings(name) {
                item(String(localized: "Réinitialiser tous les réglages du jeu")) { [catalog] in catalog.resetSettings(name) }
            }
            menu.addItem(.separator())
            if catalog.isLocal(name) {
                item(String(localized: "Supprimer la copie sur ce Mac")) { [catalog] in catalog.uninstall(name) }
            } else {
                item(String(localized: "Installer sur ce Mac…"), enabled: catalog.available.contains(name)) { [catalog] in
                    catalog.proposeInstall([name])
                }
            }
        }
    }
}

/// Retour = lancer le jeu sélectionné.
final class GameNSTableView: NSTableView {
    var onReturn: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            onReturn?()
        } else {
            super.keyDown(with: event)
        }
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}
