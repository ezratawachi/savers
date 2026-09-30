import SwiftUI

/// Afirmaciones or Visualización: the two lists that are edited the same way.
enum ItemsKind: Hashable {
    case affirmations, visualization

    var title: String {
        switch self {
        case .affirmations: "Afirmaciones"
        case .visualization: "Visualización"
        }
    }

    var noun: String {
        switch self {
        case .affirmations: "afirmación"
        case .visualization: "pregunta"
        }
    }

    var placeholder: String {
        switch self {
        case .affirmations: "Escribe tu afirmación"
        case .visualization: "Escribe la pregunta"
        }
    }
}

/// What's being edited, apart from the settings until Listo.
struct ItemsDraft: Equatable {
    struct Row: Identifiable, Equatable {
        let id = UUID()
        var label: String
        var text: String
    }

    var rows: [Row]
    var note: String

    init(_ kind: ItemsKind, _ settings: AppSettings) {
        let items = kind == .affirmations ? settings.affirmations : settings.visualization.items
        rows = items.map { Row(label: $0.label, text: $0.text) }
        if rows.isEmpty { rows = [Row(label: "", text: "")] }
        note = kind == .visualization ? settings.visualization.note : ""
    }

    var items: [Item] { rows.map { Item(label: $0.label, text: $0.text) } }

    /// Changed from what was saved (only the words count, not the rows' identities).
    func differs(from settings: AppSettings, _ kind: ItemsKind) -> Bool {
        let saved = ItemsDraft(kind, settings)
        return items != saved.items || note != saved.note
    }
}

extension AppStore {
    /// Saves an edit. Listo on Afirmaciones also counts as this month's review.
    /// Returns what to say: "Cambios guardados", "Afirmaciones revisadas", or nothing.
    func save(_ draft: ItemsDraft, _ kind: ItemsKind, inReview: Bool) -> String? {
        let due = kind == .affirmations && routine.affirmationReviewDue(reviewed: affReviewed)
        var message: String?
        if draft.differs(from: settings, kind) {
            switch kind {
            case .affirmations: setAffirmations(draft.items)
            case .visualization: setVisualization(draft.items, note: draft.note)
            }
            message = "Cambios guardados"
        } else if due {
            message = "Afirmaciones revisadas"
        }
        if kind == .affirmations { markAffirmationsReviewed() }
        return inReview ? nil : message
    }
}

/// Editing: a title (optional) and the text for each; drag to reorder, delete like any iOS list.
/// The last one can't be deleted.
struct ItemsEditor: View {
    let kind: ItemsKind
    @Binding var draft: ItemsDraft
    @FocusState private var focused: UUID?

    var body: some View {
        AppList {
            Section {
                ForEach($draft.rows) { $row in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Título (opcional)", text: $row.label)
                            .font(.reading(15, relativeTo: .subheadline).bold())
                            .foregroundStyle(.muted)
                            .accessibilityLabel("Título de \(kind.noun) \(number(row))")
                        TextField(kind.placeholder, text: $row.text, axis: .vertical)
                            .font(.reading())
                            .foregroundStyle(.ink)
                            .focused($focused, equals: row.id)
                            .accessibilityLabel("Texto de \(kind.noun) \(number(row))")
                    }
                    .padding(.vertical, 4)
                    .deleteDisabled(draft.rows.count == 1)
                }
                .onMove { draft.rows.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    guard draft.rows.count > 1 else { return }
                    draft.rows.remove(atOffsets: offsets)
                }
                Button {
                    let row = ItemsDraft.Row(label: "", text: "")
                    draft.rows.append(row)
                    focused = row.id
                } label: {
                    Label("Agregar \(kind.noun)", systemImage: "plus.circle.fill")
                        .font(.reading().bold())
                }
                .foregroundStyle(.sky)
            }
            if kind == .visualization {
                Section {
                    TextField("Opcional", text: $draft.note, axis: .vertical)
                        .font(.reading())
                        .foregroundStyle(.ink)
                } header: {
                    Text("Nota")
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollDismissesKeyboard(.interactively)
    }

    private func number(_ row: ItemsDraft.Row) -> Int { (draft.rows.firstIndex(of: row) ?? 0) + 1 }
}

/// Reading: each one with its title, as it's said in Hoy.
struct ItemsReader: View {
    let kind: ItemsKind
    let settings: AppSettings

    var body: some View {
        let items = (kind == .affirmations ? settings.affirmations : settings.visualization.items).filled
        AppList {
            Section {
                if items.isEmpty {
                    Text(kind == .affirmations ? "Todavía no tienes afirmaciones. Toca Editar para agregarlas." : "Toca Editar para agregar preguntas.")
                        .font(.reading())
                        .foregroundStyle(.muted)
                }
                ForEach(items.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 3) {
                        let label = items[i].label.trimmingCharacters(in: .whitespaces)
                        if !label.isEmpty {
                            Text(label)
                                .font(.reading(15, relativeTo: .subheadline).bold())
                                .foregroundStyle(.muted)
                        }
                        Text(items[i].text)
                            .font(.reading())
                            .foregroundStyle(.ink)
                    }
                    .padding(.vertical, 3)
                }
            } footer: {
                if kind == .visualization, !settings.visualization.note.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(settings.visualization.note).font(.reading(15, relativeTo: .subheadline))
                }
            }
        }
    }
}
