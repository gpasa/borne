import SwiftUI

/// Regroupements à milliers de valeurs (3 659 fabricants, 3 349 pilotes) :
/// une ligne chacun dans la barre latérale et un sélecteur paresseux, plutôt
/// que des milliers de lignes insérées d'un coup dans la liste.
enum GroupKind: String, CaseIterable, Identifiable {
    case manufacturer, year, source, cpu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manufacturer: "Fabricant"
        case .year: "Année"
        case .source: "Pilote"
        case .cpu: "Processeur"
        }
    }

    var symbol: String { folder("").symbol }

    func folder(_ value: String) -> Folder {
        switch self {
        case .manufacturer: .manufacturer(value)
        case .year: .year(value)
        case .source: .source(value)
        case .cpu: .cpu(value)
        }
    }

    /// La valeur choisie si le dossier courant est de ce type.
    func value(in folder: Folder?) -> String? {
        switch (self, folder) {
        case (.manufacturer, .manufacturer(let s)?), (.year, .year(let s)?),
             (.source, .source(let s)?), (.cpu, .cpu(let s)?): s
        default: nil
        }
    }

    @MainActor func items(_ c: Catalog) -> [(String, Int)] {
        switch self {
        case .manufacturer: c.manufacturers
        case .year: c.years
        case .source: c.sources
        case .cpu: c.cpus
        }
    }
}

struct GroupRow: View {
    @Environment(Catalog.self) private var catalog
    let kind: GroupKind
    @Binding var chooser: GroupKind?

    var body: some View {
        let current = kind.value(in: catalog.folder)
        Label {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title)
                    if let current {
                        Text(current).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        } icon: {
            Image(systemName: kind.symbol)
        }
        .contentShape(Rectangle())
        // Déjà sélectionnée, la ligne ne change pas de sélection : le clic
        // rouvre alors le sélecteur.
        .simultaneousGesture(TapGesture().onEnded { if current != nil { chooser = kind } })
        .tag(current.map(kind.folder) ?? Folder.chooser(kind.rawValue))
        .popover(isPresented: Binding(get: { chooser == kind }, set: { if !$0 { chooser = nil } }),
                 arrowEdge: .trailing) {
            GroupChooser(kind: kind) { value in
                catalog.folder = kind.folder(value)
                chooser = nil
            }
        }
    }
}

private struct GroupChooser: View {
    @Environment(Catalog.self) private var catalog
    let kind: GroupKind
    let pick: (String) -> Void
    @State private var filter = ""

    var body: some View {
        let all = kind.items(catalog)
        let items = filter.isEmpty ? all : all.filter { $0.0.localizedCaseInsensitiveContains(filter) }
        VStack(spacing: 0) {
            TextField("Rechercher un \(kind.title.lowercased())", text: $filter)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(items, id: \.0) { item in
                        Button {
                            pick(item.0)
                        } label: {
                            HStack {
                                Text(item.0).lineLimit(1)
                                Spacer()
                                Text("\(item.1)").foregroundStyle(.secondary).monospacedDigit()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 320, height: 440)
    }
}
